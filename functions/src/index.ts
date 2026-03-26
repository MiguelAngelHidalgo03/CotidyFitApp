import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const ADMIN_EMAIL_ALLOWLIST = new Set(['cotidyfit@gmail.com']);

async function isAdminUser(uid: string, email?: string | null): Promise<boolean> {
  const normalizedEmail = (email ?? '').trim().toLowerCase();
  if (ADMIN_EMAIL_ALLOWLIST.has(normalizedEmail)) {
    return true;
  }

  const adminSnap = await admin.firestore().collection('admin_users').doc(uid).get();
  return adminSnap.exists;
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

type ReportDoc = {
  reportedUserId?: string;
  kind?: string;
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

type RecipeLikeDoc = {
  user_id?: string;
  recipe_id?: string;
};

type RecipeRatingDoc = {
  user_id?: string;
  recipe_id?: string;
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

function _str(v: unknown): string {
  if (typeof v === 'string') return v.trim();
  if (v === null || v === undefined) return '';
  return v.toString().trim();
}

function normalizeDeleteAccountConfirmation(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z]/g, '');
}

function isValidDeleteAccountConfirmation(value: string): boolean {
  const normalized = normalizeDeleteAccountConfirmation(value);
  return normalized === 'eliminar' || normalized === 'eliminarcuenta';
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

async function deleteDocRefsInBatches(refs: FirebaseFirestore.DocumentReference[]): Promise<number> {
  if (refs.length === 0) return 0;
  const db = admin.firestore();

  let total = 0;
  // Keep batch size well under 500.
  for (const group of chunk(refs, 400)) {
    const batch = db.batch();
    for (const ref of group) batch.delete(ref);
    await batch.commit();
    total += group.length;
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

export const submitSuggestion = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const topic = _str(data?.topic);
  const message = _str(data?.message);
  const name = _str(data?.name);
  const providedEmail = _str(data?.email);

  const emailFromToken = _str((context.auth?.token as any)?.email);
  const email = providedEmail || emailFromToken;

  if (!topic) {
    throw new functions.https.HttpsError('invalid-argument', 'topic is required');
  }
  if (!message) {
    throw new functions.https.HttpsError('invalid-argument', 'message is required');
  }
  if (topic.length > 80) {
    throw new functions.https.HttpsError('invalid-argument', 'topic is too long');
  }
  if (message.length > 4000) {
    throw new functions.https.HttpsError('invalid-argument', 'message is too long');
  }

  const db = admin.firestore();
  const ref = await db.collection('suggestions').add({
    uid,
    topic,
    message,
    name: name || null,
    email: email || null,
    source: 'app',
    status: 'new',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true, id: ref.id };
});

export const deleteSuggestionAdmin = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const db = admin.firestore();
  const isAdmin = await isAdminUser(uid, context.auth?.token?.email as string | undefined);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const suggestionId = _str(data?.suggestionId);
  if (!suggestionId) {
    throw new functions.https.HttpsError('invalid-argument', 'suggestionId is required');
  }

  await db.collection('suggestions').doc(suggestionId).delete();
  return { ok: true, id: suggestionId };
});

export const deleteMyAccount = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const confirm = (data?.confirm ?? '').toString();
    if (!isValidDeleteAccountConfirmation(confirm)) {
      throw new functions.https.HttpsError('invalid-argument', 'Confirmación inválida');
    }

    const db = admin.firestore();

    // 1) Remove social graph (prevents chat recreation).
    try {
      const [friendshipsSnap, requestsSnap] = await Promise.all([
        db.collection('friendships').where('uids', 'array-contains', uid).get(),
        db.collection('friend_requests').where('uids', 'array-contains', uid).get(),
      ]);

      await deleteDocRefsInBatches(friendshipsSnap.docs.map((d) => d.ref));
      await deleteDocRefsInBatches(requestsSnap.docs.map((d) => d.ref));
    } catch (e) {
      functions.logger.warn('Failed to delete friendships/requests', e);
    }

    // 2) Purge DM chats + messages for both sides.
    try {
      const chatsSnap = await db.collection('chats').where('members', 'array-contains', uid).get();

      for (const doc of chatsSnap.docs) {
        const chatId = doc.id;
        try {
          await deleteMessagesInBatches(chatId);
        } catch (e) {
          functions.logger.warn(`Failed to delete messages for chat ${chatId}`, e);
        }

        try {
          await doc.ref.delete();
        } catch (e) {
          functions.logger.warn(`Failed to delete chat doc ${chatId}`, e);
        }
      }
    } catch (e) {
      functions.logger.warn('Failed to purge DM chats', e);
    }

    // 3) Remove from community groups (membership docs are under communityGroups/*/members/{uid}).
    try {
      const memberSnap = await db
        .collectionGroup('members')
        .where(admin.firestore.FieldPath.documentId(), '==', uid)
        .get();
      await deleteDocRefsInBatches(memberSnap.docs.map((d) => d.ref));
    } catch (e) {
      functions.logger.warn('Failed to delete community memberships', e);
    }

    // 4) Delete user identity/public docs.
    try {
      await Promise.allSettled([
        db.collection('user_public').doc(uid).delete(),
        db.collection('user_blocks').doc(uid).delete(),
        db.collection('reportCounters').doc(uid).delete(),
        db.collection('admin_users').doc(uid).delete(),
      ]);
    } catch (e) {
      functions.logger.warn('Failed to delete public/block/admin docs', e);
    }

    // 5) Delete tag reservation docs.
    try {
      const tagsSnap = await db.collection('user_tags').where('uid', '==', uid).get();
      await deleteDocRefsInBatches(tagsSnap.docs.map((d) => d.ref));
    } catch (e) {
      functions.logger.warn('Failed to delete user_tags docs', e);
    }

    // 6) Delete legacy mutedChats docs.
    try {
      const mutedSnap = await db.collection('mutedChats').where('uid', '==', uid).get();
      await deleteDocRefsInBatches(mutedSnap.docs.map((d) => d.ref));
    } catch (e) {
      functions.logger.warn('Failed to delete mutedChats docs', e);
    }

    // 6b) Delete user suggestions.
    try {
      const suggestionsSnap = await db.collection('suggestions').where('uid', '==', uid).get();
      await deleteDocRefsInBatches(suggestionsSnap.docs.map((d) => d.ref));
    } catch (e) {
      functions.logger.warn('Failed to delete suggestions docs', e);
    }

    // 7) Delete likes/ratings keyed by user_id.
    try {
      const [tl, tr, rl, rr] = await Promise.all([
        db.collection('template_likes').where('user_id', '==', uid).get(),
        db.collection('template_ratings').where('user_id', '==', uid).get(),
        db.collection('recipe_likes').where('user_id', '==', uid).get(),
        db.collection('recipe_ratings').where('user_id', '==', uid).get(),
      ]);
      await deleteDocRefsInBatches(tl.docs.map((d) => d.ref));
      await deleteDocRefsInBatches(tr.docs.map((d) => d.ref));
      await deleteDocRefsInBatches(rl.docs.map((d) => d.ref));
      await deleteDocRefsInBatches(rr.docs.map((d) => d.ref));
    } catch (e) {
      functions.logger.warn('Failed to delete likes/ratings docs', e);
    }

    // 8) Recursively delete the private user document (includes all subcollections).
    try {
      const userRef = db.collection('users').doc(uid);
      const recursiveDelete = (db as any).recursiveDelete as ((ref: any) => Promise<void>) | undefined;
      if (typeof recursiveDelete === 'function') {
        await recursiveDelete(userRef);
      } else {
        // Fallback: delete the root doc only.
        // (Subcollections won't be deleted without recursiveDelete.)
        await userRef.delete();
      }
    } catch (e) {
      functions.logger.warn('Failed to delete users/{uid} doc', e);
    }

    // 9) Delete Firebase Auth user.
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      functions.logger.warn('Failed to delete auth user', e);
    }

    return { ok: true };
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

export const onCommunityGroupMessageCreated = functions.firestore
  .document('communityGroups/{groupId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const groupId = context.params.groupId as string;
    const message = snap.data() as MessageDoc;

    const db = admin.firestore();
    const groupRef = db.collection('communityGroups').doc(groupId);

    let groupTitle = 'Comunidad';
    try {
      const groupSnap = await groupRef.get();
      const rawTitle = (groupSnap.get('title') as unknown) ?? '';
      if (typeof rawTitle === 'string' && rawTitle.trim().length > 0) {
        groupTitle = rawTitle.trim();
      }
    } catch (_) {
      // best-effort
    }

    const senderUid = (message.senderUid ?? '').trim();
    const senderName = (message.senderName ?? 'CotidyFit').toString().trim();
    const messageType = (message.type ?? 'text').toString().trim() || 'text';
    const text = (message.text ?? '').trim();

    const baseBody =
      messageType !== 'text'
        ? 'Nuevo mensaje'
        : text.length === 0
          ? 'Nuevo mensaje'
          : text.length > 120
            ? `${text.substring(0, 117)}...`
            : text;

    const body = senderName.length > 0 ? `${senderName}: ${baseBody}` : baseBody;

    // 0) Ensure group-level last message fields are always up to date.
    //    Used by the client to sort and preview groups.
    try {
      await groupRef.set(
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
      functions.logger.warn('Failed to update community group lastMessage fields', e);
    }

    // 1) Recipients: approved members in communityGroups/{groupId}/members.
    //    Membership is admin-managed. Doc id = uid.
    let memberUids: string[] = [];
    try {
      const qs = await groupRef.collection('members').where('status', '==', 'approved').get();
      memberUids = qs.docs
        .map((d) => d.id)
        .map((u) => u.trim())
        .filter((u) => u.length > 0);
    } catch (e) {
      functions.logger.warn('Failed to load community group members', e);
      return;
    }

    const recipients = senderUid.length > 0 ? memberUids.filter((u) => u !== senderUid) : memberUids;
    if (recipients.length === 0) return;

    // 2) Per-user mute (stored at users/{uid}/mutedCommunityGroups/{groupId}.muteUntil)
    const nowMs = Date.now();
    const muteSnaps = await Promise.all(
      recipients.map((uid) =>
        db.collection('users').doc(uid).collection('mutedCommunityGroups').doc(groupId).get()
      )
    );

    const recipientsForNotif: string[] = [];
    for (let i = 0; i < recipients.length; i += 1) {
      const uid = recipients[i];
      const s = muteSnaps[i];
      const muteUntil = s.exists ? (s.get('muteUntil') as unknown) : undefined;
      const muteUntilMs = (muteUntil as any)?.toMillis?.() as number | undefined;
      if (muteUntilMs && muteUntilMs > nowMs) continue;
      recipientsForNotif.push(uid);
    }

    if (recipientsForNotif.length === 0) return;

    const tokenSnaps = await Promise.all(
      recipientsForNotif.map((uid) => db.collection('users').doc(uid).collection('tokens').get())
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

    const batches = chunk(tokens, 500);
    const invalidRefs: FirebaseFirestore.DocumentReference[] = [];

    for (const batch of batches) {
      const resp = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: {
          title: groupTitle,
          body,
        },
        data: {
          groupId,
          kind: 'communityGroup',
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
      functions.logger.info(`Cleaning up ${invalidRefs.length} invalid FCM tokens (community group)`);
      await Promise.allSettled(invalidRefs.map((r) => r.delete()));
    }
  });

export const onReportCreated = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snap) => {
    const report = snap.data() as ReportDoc;
    const reportedUserId = (report?.reportedUserId ?? '').toString().trim();
    const kind = (report?.kind ?? 'dm').toString().trim() || 'dm';

    // Only track DM reports for now.
    if (kind !== 'dm') return;
    if (reportedUserId.length === 0) return;

    const db = admin.firestore();
    const ref = db.collection('reportCounters').doc(reportedUserId);

    await ref.set(
      {
        uid: reportedUserId,
        totalCount: admin.firestore.FieldValue.increment(1),
        dmCount: admin.firestore.FieldValue.increment(1),
        lastReportAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
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

// ── Recipe likes aggregate ─────────────────────────────────────────────
export const onRecipeLikeWrite = functions.firestore
  .document('recipe_likes/{likeId}')
  .onWrite(async (change) => {
    const beforeExists = change.before.exists;
    const afterExists = change.after.exists;

    if (beforeExists === afterExists) return;

    const before = (beforeExists ? (change.before.data() as RecipeLikeDoc) : undefined) ?? {};
    const after = (afterExists ? (change.after.data() as RecipeLikeDoc) : undefined) ?? {};

    const recipeId = ((after.recipe_id ?? before.recipe_id) ?? '').toString().trim();
    if (recipeId.length === 0) return;

    const delta = afterExists && !beforeExists ? 1 : !afterExists && beforeExists ? -1 : 0;
    if (delta === 0) return;

    const db = admin.firestore();
    const recipeRef = db.collection('recipes').doc(recipeId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(recipeRef);
      if (!snap.exists) return;

      const curRaw = snap.get('likes') as unknown;
      const cur = typeof curRaw === 'number' && Number.isFinite(curRaw) ? curRaw : 0;
      const next = Math.max(0, Math.min(cur + delta, 1 << 30));

      tx.set(
        recipeRef,
        { likes: next },
        { merge: true }
      );
    });
  });

// ── Recipe ratings aggregate ───────────────────────────────────────────
export const onRecipeRatingWrite = functions.firestore
  .document('recipe_ratings/{ratingId}')
  .onWrite(async (change) => {
    const before = (change.before.exists ? (change.before.data() as RecipeRatingDoc) : undefined) ?? {};
    const after = (change.after.exists ? (change.after.data() as RecipeRatingDoc) : undefined) ?? {};

    const recipeId = ((after.recipe_id ?? before.recipe_id) ?? '').toString().trim();
    if (recipeId.length === 0) return;

    const db = admin.firestore();
    const recipeRef = db.collection('recipes').doc(recipeId);

    const ratingsSnap = await db
      .collection('recipe_ratings')
      .where('recipe_id', '==', recipeId)
      .get();

    let sum = 0;
    let count = 0;
    for (const doc of ratingsSnap.docs) {
      const raw = doc.get('rating') as unknown;
      if (typeof raw !== 'number' || !Number.isFinite(raw)) continue;
      const value = Math.min(5, Math.max(1, raw));
      sum += value;
      count += 1;
    }

    const avg = count <= 0 ? 0 : sum / count;

    await recipeRef.set(
      {
        ratingSum: sum,
        ratingCount: count,
        ratingAvg: avg,
      },
      { merge: true }
    );
  });

// ── Seed sample training data (temporary utility) ─────────────────────
export const seedTrainingSampleData = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'Use POST' });
    return;
  }

  const key = ((req.header('x-seed-key') ?? req.query.key ?? '') as string).trim();
  const expected = (process.env.SEED_KEY ?? 'cotidyfit-seed-2026').trim();
  if (key !== expected) {
    res.status(401).json({ ok: false, error: 'Unauthorized' });
    return;
  }

  const db = admin.firestore();
  const ts = admin.firestore.FieldValue.serverTimestamp();

  const exercises = [
    {
      id: 'ex_sentadilla_goblet',
      name: 'Sentadilla Goblet',
      description: 'Sentadilla con mancuerna al pecho para fuerza de tren inferior.',
      muscleGroups: ['cuadriceps', 'gluteos', 'core'],
      difficultyLevel: 'intermedio',
      equipmentNeeded: 'gym',
      sportCategory: 'fuerza',
      recommendedForGoals: ['perdida_grasa', 'ganancia_muscular', 'tonificar'],
      contraindications: ['lesionesRodilla_aguda'],
      medicalWarnings: ['hipertension_no_controlada'],
      variants: [
        { name: 'Goblet ligera', description: 'Menor carga, foco en técnica.' },
        { name: 'Tempo 3-1-1', description: 'Bajada lenta de 3 segundos.' },
      ],
      imageUrl: 'https://images.unsplash.com/photo-1599058917765-a780eda07a3e',
      videoUrl: '',
    },
    {
      id: 'ex_flexiones_inclinadas',
      name: 'Flexiones inclinadas',
      description: 'Flexiones con manos elevadas para progresión de empuje.',
      muscleGroups: ['pecho', 'hombro', 'triceps'],
      difficultyLevel: 'principiante',
      equipmentNeeded: 'casa',
      sportCategory: 'fuerza',
      recommendedForGoals: ['tonificar', 'ganancia_muscular'],
      contraindications: ['lesion_hombro_aguda'],
      medicalWarnings: [],
      variants: [
        { name: 'Rodillas apoyadas', description: 'Reduce carga para iniciar.' },
      ],
      imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b',
      videoUrl: '',
    },
    {
      id: 'ex_plancha_frontal',
      name: 'Plancha frontal',
      description: 'Isométrico de core para estabilidad lumbar.',
      muscleGroups: ['core'],
      difficultyLevel: 'principiante',
      equipmentNeeded: 'none',
      sportCategory: 'movilidad',
      recommendedForGoals: ['salud', 'tonificar'],
      contraindications: ['dolor_lumbar_agudo'],
      medicalWarnings: [],
      variants: [
        { name: 'Plancha con rodillas', description: 'Versión regresada.' },
      ],
      imageUrl: 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5',
      videoUrl: '',
    },
    {
      id: 'ex_burpees',
      name: 'Burpees',
      description: 'Ejercicio HIIT de cuerpo completo.',
      muscleGroups: ['pierna', 'pecho', 'cardio'],
      difficultyLevel: 'avanzado',
      equipmentNeeded: 'none',
      sportCategory: 'hiit',
      recommendedForGoals: ['perdida_grasa', 'cardio'],
      contraindications: ['lesionesRodilla_aguda'],
      medicalWarnings: ['cardiopatia_no_controlada'],
      variants: [
        { name: 'Sin salto', description: 'Menor impacto articular.' },
      ],
      imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd',
      videoUrl: '',
    },
    {
      id: 'ex_peso_muerto_rumano_mancuernas',
      name: 'Peso muerto rumano con mancuernas',
      description: 'Bisagra de cadera para cadena posterior.',
      muscleGroups: ['isquios', 'gluteos', 'espalda_baja'],
      difficultyLevel: 'intermedio',
      equipmentNeeded: 'gym',
      sportCategory: 'fuerza',
      recommendedForGoals: ['ganancia_muscular', 'tonificar'],
      contraindications: ['dolor_lumbar_agudo'],
      medicalWarnings: [],
      variants: [
        { name: 'Una mancuerna', description: 'Más accesible para casa.' },
      ],
      imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48',
      videoUrl: '',
    },
    {
      id: 'ex_jump_jacks',
      name: 'Jumping Jacks',
      description: 'Cardio básico para elevar pulso.',
      muscleGroups: ['cardio'],
      difficultyLevel: 'principiante',
      equipmentNeeded: 'none',
      sportCategory: 'cardio',
      recommendedForGoals: ['perdida_grasa', 'cardio', 'salud'],
      contraindications: ['lesionesRodilla_aguda'],
      medicalWarnings: [],
      variants: [
        { name: 'Step jacks', description: 'Sin salto para menor impacto.' },
      ],
      imageUrl: 'https://images.unsplash.com/photo-1574680178050-55c6a6a96e0a',
      videoUrl: '',
    },
  ];

  const routines = [
    {
      id: 'rt_fullbody_casa_30',
      data: {
        name: 'Full Body Casa 30',
        description: 'Rutina completa de 30 minutos para casa.',
        difficultyLevel: 'principiante',
        goal: 'perdida_grasa',
        durationMinutes: 30,
        equipmentNeeded: 'casa',
        sportCategory: 'fuerza',
        recommendedForGoals: ['perdida_grasa', 'salud'],
        contraindications: ['espalda_aguda'],
        medicalWarnings: ['embarazo_alto_riesgo'],
        recommendedProfileTags: ['casa', 'principiante', 'perdida_grasa'],
      },
      exercises: [
        { id: '01_ex_sentadilla_goblet', exerciseId: 'ex_sentadilla_goblet', sets: 3, reps: 12, restSeconds: 60, order: 1 },
        { id: '02_ex_flexiones_inclinadas', exerciseId: 'ex_flexiones_inclinadas', sets: 3, reps: 10, restSeconds: 45, order: 2 },
        { id: '03_ex_plancha_frontal', exerciseId: 'ex_plancha_frontal', sets: 3, reps: 30, restSeconds: 40, order: 3 },
      ],
    },
    {
      id: 'rt_hiit_quemagrasa_20',
      data: {
        name: 'HIIT Quema Grasa 20',
        description: 'Sesión intensa con pausas cortas.',
        difficultyLevel: 'avanzado',
        goal: 'perdida_grasa',
        durationMinutes: 20,
        equipmentNeeded: 'none',
        sportCategory: 'hiit',
        recommendedForGoals: ['perdida_grasa', 'cardio'],
        contraindications: ['lesionesRodilla_aguda'],
        medicalWarnings: ['cardiopatia_no_controlada'],
        recommendedProfileTags: ['avanzado', 'hiit', 'cardio'],
      },
      exercises: [
        { id: '01_ex_burpees', exerciseId: 'ex_burpees', sets: 5, reps: 12, restSeconds: 30, order: 1 },
        { id: '02_ex_jump_jacks', exerciseId: 'ex_jump_jacks', sets: 5, reps: 30, restSeconds: 20, order: 2 },
      ],
    },
    {
      id: 'rt_fuerza_gym_40',
      data: {
        name: 'Fuerza Gym 40',
        description: 'Trabajo de fuerza general para gimnasio.',
        difficultyLevel: 'intermedio',
        goal: 'ganancia_muscular',
        durationMinutes: 40,
        equipmentNeeded: 'gym',
        sportCategory: 'fuerza',
        recommendedForGoals: ['ganancia_muscular', 'tonificar'],
        contraindications: ['dolor_lumbar_agudo'],
        medicalWarnings: [],
        recommendedProfileTags: ['gym', 'fuerza', 'intermedio'],
      },
      exercises: [
        { id: '01_ex_sentadilla_goblet', exerciseId: 'ex_sentadilla_goblet', sets: 4, reps: 10, restSeconds: 75, order: 1 },
        { id: '02_ex_peso_muerto_rumano_mancuernas', exerciseId: 'ex_peso_muerto_rumano_mancuernas', sets: 4, reps: 10, restSeconds: 90, order: 2 },
        { id: '03_ex_flexiones_inclinadas', exerciseId: 'ex_flexiones_inclinadas', sets: 3, reps: 12, restSeconds: 60, order: 3 },
      ],
    },
  ];

  const programs = [
    {
      id: 'pg_inicio_4s',
      data: {
        name: 'Inicio Fit 4 semanas',
        description: 'Programa base para crear hábito y mejorar condición general.',
        level: 'principiante',
        goal: 'salud',
        durationWeeks: 4,
        durationMinutes: 30,
        equipmentNeeded: 'casa',
        recommendedProfileTags: ['principiante', 'casa', 'salud'],
        contraindications: [],
        medicalWarnings: [],
      },
      days: [
        {
          id: 'lunes',
          data: { dayName: 'Lunes', focus: 'Full Body', order: 1 },
          exercises: [
            { id: '01_ex_sentadilla_goblet', exerciseId: 'ex_sentadilla_goblet', sets: 3, reps: 12, restSeconds: 60, order: 1 },
            { id: '02_ex_flexiones_inclinadas', exerciseId: 'ex_flexiones_inclinadas', sets: 3, reps: 10, restSeconds: 45, order: 2 },
          ],
        },
        {
          id: 'miercoles',
          data: { dayName: 'Miércoles', focus: 'Cardio + Core', order: 2 },
          exercises: [
            { id: '01_ex_jump_jacks', exerciseId: 'ex_jump_jacks', sets: 4, reps: 30, restSeconds: 25, order: 1 },
            { id: '02_ex_plancha_frontal', exerciseId: 'ex_plancha_frontal', sets: 3, reps: 30, restSeconds: 30, order: 2 },
          ],
        },
      ],
    },
    {
      id: 'pg_recomp_6s',
      data: {
        name: 'Recomposición 6 semanas',
        description: 'Mejora fuerza y composición corporal con 4 días por semana.',
        level: 'intermedio',
        goal: 'recomposicion',
        durationWeeks: 6,
        durationMinutes: 40,
        equipmentNeeded: 'gym',
        recommendedProfileTags: ['intermedio', 'gym', 'recomposicion'],
        contraindications: ['dolor_lumbar_agudo'],
        medicalWarnings: [],
      },
      days: [
        {
          id: 'lunes',
          data: { dayName: 'Lunes', focus: 'Pierna', order: 1 },
          exercises: [
            { id: '01_ex_sentadilla_goblet', exerciseId: 'ex_sentadilla_goblet', sets: 4, reps: 10, restSeconds: 75, order: 1 },
            { id: '02_ex_peso_muerto_rumano_mancuernas', exerciseId: 'ex_peso_muerto_rumano_mancuernas', sets: 4, reps: 10, restSeconds: 90, order: 2 },
          ],
        },
        {
          id: 'jueves',
          data: { dayName: 'Jueves', focus: 'Push + Core', order: 2 },
          exercises: [
            { id: '01_ex_flexiones_inclinadas', exerciseId: 'ex_flexiones_inclinadas', sets: 4, reps: 12, restSeconds: 60, order: 1 },
            { id: '02_ex_plancha_frontal', exerciseId: 'ex_plancha_frontal', sets: 3, reps: 40, restSeconds: 35, order: 2 },
          ],
        },
      ],
    },
  ];

  const batch = db.batch();

  for (const ex of exercises) {
    const ref = db.collection('exercises').doc(ex.id);
    const { id, ...data } = ex;
    batch.set(ref, { ...data, createdAt: ts, updatedAt: ts }, { merge: true });
  }

  for (const routine of routines) {
    const rRef = db.collection('routines').doc(routine.id);
    batch.set(rRef, { ...routine.data, createdAt: ts, updatedAt: ts }, { merge: true });
    for (const ex of routine.exercises) {
      const eRef = rRef.collection('exercises').doc(ex.id);
      batch.set(eRef, { ...ex, updatedAt: ts }, { merge: true });
    }
  }

  for (const program of programs) {
    const pRef = db.collection('weeklyPrograms').doc(program.id);
    batch.set(pRef, { ...program.data, createdAt: ts, updatedAt: ts }, { merge: true });
    for (const day of program.days) {
      const dRef = pRef.collection('days').doc(day.id);
      batch.set(dRef, { ...day.data, updatedAt: ts }, { merge: true });
      for (const ex of day.exercises) {
        const eRef = dRef.collection('exercises').doc(ex.id);
        batch.set(eRef, { ...ex, updatedAt: ts }, { merge: true });
      }
    }
  }

  await batch.commit();

  res.status(200).json({
    ok: true,
    inserted: {
      exercises: exercises.length,
      routines: routines.length,
      programs: programs.length,
    },
  });
});

// ── Seed sample achievements catalog (temporary utility) ──────────────
export const seedAchievementsCatalog = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'Use POST' });
    return;
  }

  const key = ((req.header('x-seed-key') ?? req.query.key ?? '') as string).trim();
  const expected = (process.env.SEED_KEY ?? 'cotidyfit-seed-2026').trim();
  if (key !== expected) {
    res.status(401).json({ ok: false, error: 'Unauthorized' });
    return;
  }

  const db = admin.firestore();
  const ts = admin.firestore.FieldValue.serverTimestamp();

  const achievements = [
    {
      id: 'first_workout',
      title: 'Primer entrenamiento',
      description: 'Completa tu primer entrenamiento.',
      icon: 'fitness_center_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 1,
    },
    {
      id: 'streak_7_days',
      title: 'Constante 7 días',
      description: 'Mantén una racha de 7 días.',
      icon: 'local_fire_department_outlined',
      category: 'racha',
      conditionType: 'streak_days',
      conditionValue: 7,
    },
    {
      id: 'hydrated_2000',
      title: 'Hidratado',
      description: 'Llega a 2000 ml de agua en un día.',
      icon: 'water_drop_outlined',
      category: 'nutricion',
      conditionType: 'water_ml',
      conditionValue: 2000,
    },
    {
      id: 'mind_strong',
      title: 'Mente fuerte',
      description: 'Registra meditación en 5 días.',
      icon: 'self_improvement_outlined',
      category: 'mentalidad',
      conditionType: 'meditation_days',
      conditionValue: 5,
    },
    {
      id: 'workouts_10',
      title: '10 entrenamientos',
      description: 'Completa 10 entrenamientos.',
      icon: 'military_tech_outlined',
      category: 'entrenamiento',
      conditionType: 'workouts_completed',
      conditionValue: 10,
    },
    {
      id: 'first_week_program',
      title: 'Primera semana completada',
      description: 'Completa todos los entrenamientos de una semana planificada.',
      icon: 'event_available_outlined',
      category: 'progreso',
      conditionType: 'weekly_program_completed',
      conditionValue: 1,
    },
  ];

  const batch = db.batch();
  for (const a of achievements) {
    const ref = db.collection('achievementsCatalog').doc(a.id);
    const { id, ...data } = a;
    batch.set(ref, { ...data, createdAt: ts }, { merge: true });
  }

  await batch.commit();

  res.status(200).json({
    ok: true,
    inserted: achievements.length,
  });
});

export const onUserTaskReminderChanged = functions.firestore
  .document('users/{userId}/tasks/{taskId}')
  .onWrite(async (change, context) => {
    const userId = (context.params.userId as string | undefined)?.trim() ?? '';
    if (!userId) return;

    const after = change.after.exists ? change.after.data() : undefined;
    if (!after) return;

    const enabled = after.notificationEnabled === true;
    if (!enabled) return;

    const before = change.before.exists ? change.before.data() : undefined;
    const beforeEnabled = before?.notificationEnabled === true;
    const beforeDue = before?.dueDate as FirebaseFirestore.Timestamp | undefined;
    const afterDue = after.dueDate as FirebaseFirestore.Timestamp | undefined;

    const dueChanged =
      (beforeDue?.toMillis?.() ?? 0) !== (afterDue?.toMillis?.() ?? 0);

    if (beforeEnabled && !dueChanged) return;

    const title = (after.title ?? 'Tarea pendiente').toString().trim() || 'Tarea pendiente';
    const due = afterDue?.toDate?.();
    const dueText = due
      ? `${String(due.getDate()).padStart(2, '0')}/${String(due.getMonth() + 1).padStart(2, '0')}`
      : '';
    const body = dueText
      ? `Recordatorio activado · Te avisaremos el ${dueText}.`
      : 'Recordatorio activado en CotidyFit.';

    const tokensSnap = await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .collection('tokens')
      .get();

    const tokens = tokensSnap.docs
      .map((d) => (d.get('token') ?? d.id).toString().trim())
      .filter((t: string) => t.length > 0);

    if (tokens.length === 0) return;

    const result = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      android: {
        notification: {
          channelId: 'task_reminders',
        },
      },
      data: {
        type: 'task_reminder',
        taskId: (context.params.taskId as string) ?? '',
      },
    });

    const invalid: string[] = [];
    for (let i = 0; i < result.responses.length; i++) {
      const r = result.responses[i];
      if (!r.success && isInvalidTokenError(r.error?.code)) {
        invalid.push(tokens[i]);
      }
    }

    if (invalid.length > 0) {
      const db = admin.firestore();
      const batch = db.batch();
      for (const token of invalid) {
        batch.delete(db.collection('users').doc(userId).collection('tokens').doc(token));
      }
      await batch.commit();
    }
  });

export const seedWeeklyChallenges = functions.https.onCall(async (_data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const isAdmin = await isAdminUser(uid, context.auth?.token?.email as string | undefined);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin privileges required');
  }

  const challenges = weeklyChallengesSeedData();

  const db = admin.firestore();
  const batch = db.batch();
  for (const challenge of challenges) {
    const ref = db.collection('weeklyChallenges').doc(challenge.id);
    batch.set(
      ref,
      {
        ...challenge,
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();

  return { ok: true, seeded: challenges.length };
});

type WeeklyChallengeSeed = {
  id: string;
  order: number;
  title: string;
  description: string;
  targetType: string;
  targetValue: number;
  rewardCFBonus: number;
};

function weeklyChallengesSeedData(): WeeklyChallengeSeed[] {
  // Source: admin_panel/retos_semanales.txt
  return [
    {
      id: 'weekly_steps_45k',
      order: 1,
      title: '45k pasos en 7 días',
      description: 'Acumula 45.000 pasos esta semana.',
      targetType: 'steps',
      targetValue: 45000,
      rewardCFBonus: 12,
    },
    {
      id: 'weekly_hydration_14l',
      order: 2,
      title: '14L de hidratación',
      description: 'Llega a 14 litros de agua durante la semana.',
      targetType: 'waterMl',
      targetValue: 14000,
      rewardCFBonus: 10,
    },
    {
      id: 'weekly_habits_18',
      order: 3,
      title: '18 hábitos completados',
      description: 'Completa al menos 18 hábitos en total.',
      targetType: 'habitsCompleted',
      targetValue: 18,
      rewardCFBonus: 14,
    },
    {
      id: 'weekly_workouts_5',
      order: 4,
      title: '5 entrenamientos',
      description: 'Marca 5 entrenamientos completados en la semana.',
      targetType: 'workouts',
      targetValue: 5,
      rewardCFBonus: 15,
    },
    {
      id: 'weekly_consistency_7',
      order: 5,
      title: 'Semana consistente',
      description: 'Registra actividad útil los 7 días de la semana.',
      targetType: 'activeDays',
      targetValue: 7,
      rewardCFBonus: 18,
    },
  ];
}

// ── Seed weekly challenges (temporary utility) ───────────────────────
export const seedWeeklyChallengesHttp = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'Use POST' });
    return;
  }

  const key = ((req.header('x-seed-key') ?? req.query.key ?? '') as string).trim();
  const expected = (process.env.SEED_KEY ?? 'cotidyfit-seed-2026').trim();
  if (key !== expected) {
    res.status(401).json({ ok: false, error: 'Unauthorized' });
    return;
  }

  const challenges = weeklyChallengesSeedData();
  const db = admin.firestore();
  const batch = db.batch();
  for (const challenge of challenges) {
    const ref = db.collection('weeklyChallenges').doc(challenge.id);
    batch.set(
      ref,
      {
        ...challenge,
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();

  res.status(200).json({ ok: true, seeded: challenges.length });
});

function asString(value: unknown): string {
  if (value == null) return '';
  return value.toString().trim();
}

function asInt(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.round(value);
  if (typeof value === 'string') {
    const n = Number.parseInt(value, 10);
    return Number.isFinite(n) ? n : 0;
  }
  return 0;
}

function asBool(value: unknown): boolean {
  return value === true;
}

async function applyWeeklyChallengeCommunityDelta(params: {
  challengeId: string;
  weekId: string;
  participantsDelta: number;
  completedDelta: number;
  resetIfWeekMismatch: boolean;
}): Promise<void> {
  const { challengeId, weekId, participantsDelta, completedDelta, resetIfWeekMismatch } = params;
  const safeWeekId = weekId.trim();
  const safeChallengeId = challengeId.trim();
  if (safeChallengeId.length === 0 || safeWeekId.length === 0) return;

  const db = admin.firestore();
  const ref = db.collection('weeklyChallenges').doc(safeChallengeId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = (snap.data() ?? {}) as FirebaseFirestore.DocumentData;

    const currentWeekId = asString(data.communityWeekId);
    if (currentWeekId.length > 0 && currentWeekId != safeWeekId && !resetIfWeekMismatch) {
      return;
    }

    let participants = currentWeekId == safeWeekId ? asInt(data.communityParticipants) : 0;
    let completed = currentWeekId == safeWeekId ? asInt(data.communityCompleted) : 0;

    participants = Math.max(0, participants + participantsDelta);
    completed = Math.max(0, completed + completedDelta);
    if (completed > participants) completed = participants;

    const pct = participants <= 0 ? 0 : Math.round((completed / participants) * 100);

    tx.set(
      ref,
      {
        communityWeekId: safeWeekId,
        communityParticipants: participants,
        communityCompleted: completed,
        communityCompletionPct: pct,
        communityUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

// Aggregate weekly challenge completion percentage.
// This updates fields on weeklyChallenges/{challengeId} for the active weekId.
export const onWeeklyChallengeProgressWrite = functions.firestore
  .document('users/{uid}/weeklyChallengeProgress/{challengeId}')
  .onWrite(async (change, context) => {
    const challengeId = (context.params.challengeId as string) ?? '';

    const before = change.before.exists ? (change.before.data() as FirebaseFirestore.DocumentData) : null;
    const after = change.after.exists ? (change.after.data() as FirebaseFirestore.DocumentData) : null;

    const beforeWeekId = asString(before?.weekId);
    const afterWeekId = asString(after?.weekId);
    const beforeCompleted = asBool(before?.completed);
    const afterCompleted = asBool(after?.completed);

    const ops: Promise<void>[] = [];
    const enqueue = (p: {
      weekId: string;
      participantsDelta: number;
      completedDelta: number;
      resetIfWeekMismatch: boolean;
    }) => {
      if (p.weekId.trim().length === 0) return;
      ops.push(applyWeeklyChallengeCommunityDelta({ challengeId, ...p }));
    };

    // Create
    if (before == null && after != null) {
      enqueue({
        weekId: afterWeekId,
        participantsDelta: 1,
        completedDelta: afterCompleted ? 1 : 0,
        resetIfWeekMismatch: true,
      });
    }

    // Delete
    if (before != null && after == null) {
      enqueue({
        weekId: beforeWeekId,
        participantsDelta: -1,
        completedDelta: beforeCompleted ? -1 : 0,
        resetIfWeekMismatch: false,
      });
    }

    // Update
    if (before != null && after != null) {
      if (beforeWeekId != afterWeekId) {
        // Moved between weeks (challenge reused across weeks).
        enqueue({
          weekId: beforeWeekId,
          participantsDelta: -1,
          completedDelta: beforeCompleted ? -1 : 0,
          resetIfWeekMismatch: false,
        });
        enqueue({
          weekId: afterWeekId,
          participantsDelta: 1,
          completedDelta: afterCompleted ? 1 : 0,
          resetIfWeekMismatch: true,
        });
      } else if (beforeCompleted != afterCompleted) {
        enqueue({
          weekId: afterWeekId,
          participantsDelta: 0,
          completedDelta: afterCompleted ? 1 : -1,
          resetIfWeekMismatch: false,
        });
      }
    }

    if (ops.length === 0) return;
    await Promise.all(ops);
  });
