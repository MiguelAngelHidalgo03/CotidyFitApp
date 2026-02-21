import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

type ChatDoc = {
  members?: string[];
  kind?: string;
  muteUntil?: FirebaseFirestore.Timestamp;
  muteUntilByUser?: Record<string, FirebaseFirestore.Timestamp>;
  hiddenForUsers?: string[];
};

type MessageDoc = {
  senderUid?: string;
  senderName?: string;
  text?: string;
  type?: string;
  clientHandledUnread?: boolean;
};

type TemplateLikeDoc = {
  user_id?: string;
  template_id?: string;
};

type TemplateRatingDoc = {
  user_id?: string;
  template_id?: string;
  rating?: number;
};

function chunk<T>(items: T[], size: number): T[][] {
  if (size <= 0) return [items];
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

function isInvalidTokenError(code?: string): boolean {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  );
}

async function deleteMessagesInBatches(chatId: string): Promise<number> {
  const db = admin.firestore();
  const chatRef = db.collection('chats').doc(chatId);

  let total = 0;
  // Keep batch size well under 500 to leave headroom.
  const limit = 400;

  // Delete until the collection is empty.
  // This is safe for large chats and avoids loading all messages at once.
  while (true) {
    const qs = await chatRef.collection('messages').limit(limit).get();
    if (qs.empty) break;

    const batch = db.batch();
    for (const doc of qs.docs) batch.delete(doc.ref);
    await batch.commit();
    total += qs.size;
  }
  return total;
}

type DeleteChatCascadeMode = 'purge' | 'clear';

export const deleteChatCascade = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const chatId = (data?.chatId ?? '').toString().trim();
  const mode = ((data?.mode ?? 'purge').toString().trim() as DeleteChatCascadeMode) || 'purge';

  if (chatId.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'chatId is required');
  }
  if (mode !== 'purge' && mode !== 'clear') {
    throw new functions.https.HttpsError('invalid-argument', 'mode must be purge|clear');
  }

  const db = admin.firestore();
  const chatRef = db.collection('chats').doc(chatId);
  const chatSnap = await chatRef.get();

  if (!chatSnap.exists) {
    // Nothing to delete.
    return { ok: true, deletedMessages: 0, deletedChat: false, mode };
  }

  const membersRaw = chatSnap.get('members') as unknown;
  const members = Array.isArray(membersRaw)
    ? membersRaw.map((m) => (m ?? '').toString().trim()).filter((m) => m.length > 0)
    : [];

  if (!members.includes(uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Not a member of this chat');
  }

  const chatData = (chatSnap.data() ?? {}) as FirebaseFirestore.DocumentData;

  const deletedMessages = await deleteMessagesInBatches(chatId);

  if (mode === 'purge') {
    await chatRef.delete();
    return { ok: true, deletedMessages, deletedChat: true, mode };
  }

  // mode === 'clear': delete & recreate the chat document (friendship is not modified).
  await chatRef.delete();
  await chatRef.set(
    {
      ...chatData,
      lastMessage: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: chatData.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: false }
  );

  return { ok: true, deletedMessages, deletedChat: true, mode };
});

export const onMessageCreated = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const chatId = context.params.chatId as string;
    const message = snap.data() as MessageDoc;

    const chatRef = admin.firestore().collection('chats').doc(chatId);
    const chatSnap = await chatRef.get();
    const chat = chatSnap.data() as ChatDoc | undefined;

    const members = (chat?.members ?? []).filter((m) => typeof m === 'string' && m.trim().length > 0);
    if (members.length < 2) return;

    const senderUid = (message.senderUid ?? '').trim();
    const senderName = (message.senderName ?? 'CotidyFit').trim();
    const messageType = (message.type ?? 'text').toString().trim() || 'text';
    const text = (message.text ?? '').trim();
    const clientHandledUnread = message.clientHandledUnread === true;

    const body =
      messageType !== 'text'
        ? 'Nuevo mensaje'
        : text.length === 0
          ? 'Nuevo mensaje'
          : text.length > 120
            ? `${text.substring(0, 117)}...`
            : text;

    const recipients = senderUid.length > 0 ? members.filter((m) => m !== senderUid) : members;
    if (recipients.length === 0) return;

    // 0) Ensure chat-level last message fields are always up to date.
    //    This is used by the client to sort and preview chats.
    try {
      await admin
        .firestore()
        .collection('chats')
        .doc(chatId)
        .set(
          {
            lastMessage: {
              senderUid,
              senderName,
              type: messageType,
              text,
              createdAtMs: Date.now(),
            },
            lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
            lastMessageSender: senderUid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
    } catch (e) {
      functions.logger.warn('Failed to update lastMessage fields', e);
    }

    // 1) WhatsApp-style unread counters (does NOT depend on mute).
    //    unreadCountByUser.{recipient}++ for all recipients.
    //    Also unhide chats for recipients if they deleted the conversation locally.
    try {
      if (!clientHandledUnread) {
        await admin.firestore().runTransaction(async (tx) => {
          const s = await tx.get(chatRef);
          const d = (s.data() ?? {}) as FirebaseFirestore.DocumentData;

          // unreadCountByUser: ensure map-like, then bump recipients.
          const rawUnread = d.unreadCountByUser;
          const unread: Record<string, number> =
            rawUnread && typeof rawUnread === 'object' && !Array.isArray(rawUnread)
              ? { ...(rawUnread as Record<string, any>) }
              : {};

          for (const r of recipients) {
            const cur = unread[r];
            const curNum = typeof cur === 'number' && Number.isFinite(cur) ? cur : 0;
            unread[r] = curNum + 1;
          }

          // hiddenForUsers: remove recipients from the array to make chats reappear.
          const rawHidden = d.hiddenForUsers;
          const hidden: string[] = Array.isArray(rawHidden)
            ? rawHidden
                .map((x) => (x ?? '').toString())
                .filter((x) => x.trim().length > 0)
            : [];
          const toRemove = new Set(recipients);
          const newHidden = hidden.filter((u) => !toRemove.has(u));

          tx.set(
            chatRef,
            {
              unreadCountByUser: unread,
              hiddenForUsers: newHidden,
            },
            { merge: true }
          );
        });
      }
    } catch (e) {
      functions.logger.warn('Failed to update unreadCountByUser', e);
    }

    // 2) Mute handling for notifications.
    //    If muted for a recipient (muteUntilByUser[uid] > now) skip sending FCM.
    const nowMs = Date.now();
    const globalMuteUntilMs = (chat?.muteUntil as any)?.toMillis?.() as number | undefined;
    const muteByUser = (chat?.muteUntilByUser ?? {}) as Record<string, any>;
    const recipientsForNotif = recipients.filter((r) => {
      if (globalMuteUntilMs && globalMuteUntilMs > nowMs) return false;
      const ts = muteByUser[r];
      const ms = ts?.toMillis?.() as number | undefined;
      return !(ms && ms > nowMs);
    });

    if (recipientsForNotif.length === 0) return;

    const tokenSnaps = await Promise.all(
      recipientsForNotif.map((uid) => admin.firestore().collection('users').doc(uid).collection('tokens').get())
    );

    const tokenToRef = new Map<string, FirebaseFirestore.DocumentReference>();
    for (const qs of tokenSnaps) {
      for (const doc of qs.docs) {
        const raw = (doc.get('token') as string | undefined) ?? doc.id;
        const token = raw.trim();
        if (token.length > 0) tokenToRef.set(token, doc.ref);
      }
    }

    const tokens = [...tokenToRef.keys()];

    if (tokens.length === 0) return;

    // Keep payload small; include chatId for deep-linking.
    const batches = chunk(tokens, 500);
    const invalidRefs: FirebaseFirestore.DocumentReference[] = [];

    for (const batch of batches) {
      const resp = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: {
          title: senderName.length > 0 ? senderName : 'CotidyFit',
          body,
        },
        data: {
          chatId,
          kind: (chat?.kind ?? 'dm').toString(),
          type: messageType,
        },
      });

      resp.responses.forEach((r, i) => {
        if (r.success) return;
        const code = r.error?.code;
        if (!isInvalidTokenError(code)) return;

        const t = batch[i];
        const ref = tokenToRef.get(t);
        if (ref) invalidRefs.push(ref);
      });
    }

    if (invalidRefs.length > 0) {
      functions.logger.info(`Cleaning up ${invalidRefs.length} invalid FCM tokens`);
      await Promise.allSettled(invalidRefs.map((r) => r.delete()));
    }
  });

export const onTemplateLikeWrite = functions.firestore
  .document('template_likes/{likeId}')
  .onWrite(async (change) => {
    const beforeExists = change.before.exists;
    const afterExists = change.after.exists;

    if (beforeExists === afterExists) {
      // Update without create/delete does not affect totals.
      return;
    }

    const before = (beforeExists ? (change.before.data() as TemplateLikeDoc) : undefined) ?? {};
    const after = (afterExists ? (change.after.data() as TemplateLikeDoc) : undefined) ?? {};

    const templateId = ((after.template_id ?? before.template_id) ?? '').toString().trim();
    if (templateId.length === 0) return;

    const delta = afterExists && !beforeExists ? 1 : !afterExists && beforeExists ? -1 : 0;
    if (delta === 0) return;

    const db = admin.firestore();
    const templateRef = db.collection('templates').doc(templateId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(templateRef);
      if (!snap.exists) return;

      const curRaw = snap.get('total_likes') as unknown;
      const cur = typeof curRaw === 'number' && Number.isFinite(curRaw) ? curRaw : 0;
      const next = Math.max(0, Math.min(cur + delta, 1 << 30));

      tx.set(
        templateRef,
        {
          total_likes: next,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  });

export const onTemplateRatingWrite = functions.firestore
  .document('template_ratings/{ratingId}')
  .onWrite(async (change) => {
    const beforeExists = change.before.exists;
    const afterExists = change.after.exists;

    const before = (beforeExists ? (change.before.data() as TemplateRatingDoc) : undefined) ?? {};
    const after = (afterExists ? (change.after.data() as TemplateRatingDoc) : undefined) ?? {};

    const templateId = ((after.template_id ?? before.template_id) ?? '').toString().trim();
    if (templateId.length === 0) return;

    const beforeRatingRaw = before.rating;
    const afterRatingRaw = after.rating;
    const beforeRating =
      typeof beforeRatingRaw === 'number' && Number.isFinite(beforeRatingRaw)
        ? Math.min(5, Math.max(1, Math.trunc(beforeRatingRaw)))
        : 0;
    const afterRating =
      typeof afterRatingRaw === 'number' && Number.isFinite(afterRatingRaw)
        ? Math.min(5, Math.max(1, Math.trunc(afterRatingRaw)))
        : 0;

    let deltaSum = 0;
    let deltaCount = 0;

    if (!beforeExists && afterExists) {
      if (afterRating > 0) {
        deltaSum = afterRating;
        deltaCount = 1;
      }
    } else if (beforeExists && !afterExists) {
      if (beforeRating > 0) {
        deltaSum = -beforeRating;
        deltaCount = -1;
      }
    } else if (beforeExists && afterExists) {
      // Update: only sum changes.
      if (beforeRating > 0 && afterRating > 0) {
        deltaSum = afterRating - beforeRating;
      }
    }

    if (deltaSum === 0 && deltaCount === 0) return;

    const db = admin.firestore();
    const templateRef = db.collection('templates').doc(templateId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(templateRef);
      if (!snap.exists) return;

      const sumRaw = snap.get('rating_sum') as unknown;
      const countRaw = snap.get('rating_count') as unknown;

      const curSum = typeof sumRaw === 'number' && Number.isFinite(sumRaw) ? sumRaw : 0;
      const curCount = typeof countRaw === 'number' && Number.isFinite(countRaw) ? countRaw : 0;

      const nextCount = Math.max(0, Math.min(curCount + deltaCount, 1 << 30));
      const nextSum = nextCount <= 0 ? 0 : Math.max(0, curSum + deltaSum);
      const nextAvg = nextCount <= 0 ? 0 : nextSum / nextCount;

      tx.set(
        templateRef,
        {
          rating_sum: nextSum,
          rating_count: nextCount,
          avg_rating: nextAvg,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  });
