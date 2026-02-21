"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMessageCreated = exports.deleteChatCascade = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
function chunk(items, size) {
    if (size <= 0)
        return [items];
    const out = [];
    for (let i = 0; i < items.length; i += size) {
        out.push(items.slice(i, i + size));
    }
    return out;
}
function isInvalidTokenError(code) {
    return (code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/invalid-argument');
}
async function deleteMessagesInBatches(chatId) {
    const db = admin.firestore();
    const chatRef = db.collection('chats').doc(chatId);
    let total = 0;
    // Keep batch size well under 500 to leave headroom.
    const limit = 400;
    // Delete until the collection is empty.
    // This is safe for large chats and avoids loading all messages at once.
    while (true) {
        const qs = await chatRef.collection('messages').limit(limit).get();
        if (qs.empty)
            break;
        const batch = db.batch();
        for (const doc of qs.docs)
            batch.delete(doc.ref);
        await batch.commit();
        total += qs.size;
    }
    return total;
}
exports.deleteChatCascade = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const chatId = (data?.chatId ?? '').toString().trim();
    const mode = (data?.mode ?? 'purge').toString().trim() || 'purge';
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
    const membersRaw = chatSnap.get('members');
    const members = Array.isArray(membersRaw)
        ? membersRaw.map((m) => (m ?? '').toString().trim()).filter((m) => m.length > 0)
        : [];
    if (!members.includes(uid)) {
        throw new functions.https.HttpsError('permission-denied', 'Not a member of this chat');
    }
    const chatData = (chatSnap.data() ?? {});
    const deletedMessages = await deleteMessagesInBatches(chatId);
    if (mode === 'purge') {
        await chatRef.delete();
        return { ok: true, deletedMessages, deletedChat: true, mode };
    }
    // mode === 'clear': delete & recreate the chat document (friendship is not modified).
    await chatRef.delete();
    await chatRef.set({
        ...chatData,
        lastMessage: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: chatData.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: false });
    return { ok: true, deletedMessages, deletedChat: true, mode };
});
exports.onMessageCreated = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
    const chatId = context.params.chatId;
    const message = snap.data();
    const chatRef = admin.firestore().collection('chats').doc(chatId);
    const chatSnap = await chatRef.get();
    const chat = chatSnap.data();
    const members = (chat?.members ?? []).filter((m) => typeof m === 'string' && m.trim().length > 0);
    if (members.length < 2)
        return;
    const senderUid = (message.senderUid ?? '').trim();
    const senderName = (message.senderName ?? 'CotidyFit').trim();
    const messageType = (message.type ?? 'text').toString().trim() || 'text';
    const text = (message.text ?? '').trim();
    const clientHandledUnread = message.clientHandledUnread === true;
    const body = messageType !== 'text'
        ? 'Nuevo mensaje'
        : text.length === 0
            ? 'Nuevo mensaje'
            : text.length > 120
                ? `${text.substring(0, 117)}...`
                : text;
    const recipients = senderUid.length > 0 ? members.filter((m) => m !== senderUid) : members;
    if (recipients.length === 0)
        return;
    // 0) Ensure chat-level last message fields are always up to date.
    //    This is used by the client to sort and preview chats.
    try {
        await admin
            .firestore()
            .collection('chats')
            .doc(chatId)
            .set({
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
        }, { merge: true });
    }
    catch (e) {
        functions.logger.warn('Failed to update lastMessage fields', e);
    }
    // 1) WhatsApp-style unread counters (does NOT depend on mute).
    //    unreadCountByUser.{recipient}++ for all recipients.
    //    Also unhide chats for recipients if they deleted the conversation locally.
    try {
        if (!clientHandledUnread) {
            await admin.firestore().runTransaction(async (tx) => {
                const s = await tx.get(chatRef);
                const d = (s.data() ?? {});
                // unreadCountByUser: ensure map-like, then bump recipients.
                const rawUnread = d.unreadCountByUser;
                const unread = rawUnread && typeof rawUnread === 'object' && !Array.isArray(rawUnread)
                    ? { ...rawUnread }
                    : {};
                for (const r of recipients) {
                    const cur = unread[r];
                    const curNum = typeof cur === 'number' && Number.isFinite(cur) ? cur : 0;
                    unread[r] = curNum + 1;
                }
                // hiddenForUsers: remove recipients from the array to make chats reappear.
                const rawHidden = d.hiddenForUsers;
                const hidden = Array.isArray(rawHidden)
                    ? rawHidden
                        .map((x) => (x ?? '').toString())
                        .filter((x) => x.trim().length > 0)
                    : [];
                const toRemove = new Set(recipients);
                const newHidden = hidden.filter((u) => !toRemove.has(u));
                tx.set(chatRef, {
                    unreadCountByUser: unread,
                    hiddenForUsers: newHidden,
                }, { merge: true });
            });
        }
    }
    catch (e) {
        functions.logger.warn('Failed to update unreadCountByUser', e);
    }
    // 2) Mute handling for notifications.
    //    If muted for a recipient (muteUntilByUser[uid] > now) skip sending FCM.
    const nowMs = Date.now();
    const globalMuteUntilMs = chat?.muteUntil?.toMillis?.();
    const muteByUser = (chat?.muteUntilByUser ?? {});
    const recipientsForNotif = recipients.filter((r) => {
        if (globalMuteUntilMs && globalMuteUntilMs > nowMs)
            return false;
        const ts = muteByUser[r];
        const ms = ts?.toMillis?.();
        return !(ms && ms > nowMs);
    });
    if (recipientsForNotif.length === 0)
        return;
    const tokenSnaps = await Promise.all(recipientsForNotif.map((uid) => admin.firestore().collection('users').doc(uid).collection('tokens').get()));
    const tokenToRef = new Map();
    for (const qs of tokenSnaps) {
        for (const doc of qs.docs) {
            const raw = doc.get('token') ?? doc.id;
            const token = raw.trim();
            if (token.length > 0)
                tokenToRef.set(token, doc.ref);
        }
    }
    const tokens = [...tokenToRef.keys()];
    if (tokens.length === 0)
        return;
    // Keep payload small; include chatId for deep-linking.
    const batches = chunk(tokens, 500);
    const invalidRefs = [];
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
            if (r.success)
                return;
            const code = r.error?.code;
            if (!isInvalidTokenError(code))
                return;
            const t = batch[i];
            const ref = tokenToRef.get(t);
            if (ref)
                invalidRefs.push(ref);
        });
    }
    if (invalidRefs.length > 0) {
        functions.logger.info(`Cleaning up ${invalidRefs.length} invalid FCM tokens`);
        await Promise.allSettled(invalidRefs.map((r) => r.delete()));
    }
});
