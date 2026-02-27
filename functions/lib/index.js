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
exports.onUserTaskReminderChanged = exports.seedAchievementsCatalog = exports.seedTrainingSampleData = exports.onRecipeRatingWrite = exports.onRecipeLikeWrite = exports.onTemplateRatingWrite = exports.onTemplateLikeWrite = exports.onMessageCreated = exports.deleteChatCascade = void 0;
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
exports.onTemplateLikeWrite = functions.firestore
    .document('template_likes/{likeId}')
    .onWrite(async (change) => {
    const beforeExists = change.before.exists;
    const afterExists = change.after.exists;
    if (beforeExists === afterExists) {
        // Update without create/delete does not affect totals.
        return;
    }
    const before = (beforeExists ? change.before.data() : undefined) ?? {};
    const after = (afterExists ? change.after.data() : undefined) ?? {};
    const templateId = ((after.template_id ?? before.template_id) ?? '').toString().trim();
    if (templateId.length === 0)
        return;
    const delta = afterExists && !beforeExists ? 1 : !afterExists && beforeExists ? -1 : 0;
    if (delta === 0)
        return;
    const db = admin.firestore();
    const templateRef = db.collection('templates').doc(templateId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(templateRef);
        if (!snap.exists)
            return;
        const curRaw = snap.get('total_likes');
        const cur = typeof curRaw === 'number' && Number.isFinite(curRaw) ? curRaw : 0;
        const next = Math.max(0, Math.min(cur + delta, 1 << 30));
        tx.set(templateRef, {
            total_likes: next,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
});
exports.onTemplateRatingWrite = functions.firestore
    .document('template_ratings/{ratingId}')
    .onWrite(async (change) => {
    const beforeExists = change.before.exists;
    const afterExists = change.after.exists;
    const before = (beforeExists ? change.before.data() : undefined) ?? {};
    const after = (afterExists ? change.after.data() : undefined) ?? {};
    const templateId = ((after.template_id ?? before.template_id) ?? '').toString().trim();
    if (templateId.length === 0)
        return;
    const beforeRatingRaw = before.rating;
    const afterRatingRaw = after.rating;
    const beforeRating = typeof beforeRatingRaw === 'number' && Number.isFinite(beforeRatingRaw)
        ? Math.min(5, Math.max(1, Math.trunc(beforeRatingRaw)))
        : 0;
    const afterRating = typeof afterRatingRaw === 'number' && Number.isFinite(afterRatingRaw)
        ? Math.min(5, Math.max(1, Math.trunc(afterRatingRaw)))
        : 0;
    let deltaSum = 0;
    let deltaCount = 0;
    if (!beforeExists && afterExists) {
        if (afterRating > 0) {
            deltaSum = afterRating;
            deltaCount = 1;
        }
    }
    else if (beforeExists && !afterExists) {
        if (beforeRating > 0) {
            deltaSum = -beforeRating;
            deltaCount = -1;
        }
    }
    else if (beforeExists && afterExists) {
        // Update: only sum changes.
        if (beforeRating > 0 && afterRating > 0) {
            deltaSum = afterRating - beforeRating;
        }
    }
    if (deltaSum === 0 && deltaCount === 0)
        return;
    const db = admin.firestore();
    const templateRef = db.collection('templates').doc(templateId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(templateRef);
        if (!snap.exists)
            return;
        const sumRaw = snap.get('rating_sum');
        const countRaw = snap.get('rating_count');
        const curSum = typeof sumRaw === 'number' && Number.isFinite(sumRaw) ? sumRaw : 0;
        const curCount = typeof countRaw === 'number' && Number.isFinite(countRaw) ? countRaw : 0;
        const nextCount = Math.max(0, Math.min(curCount + deltaCount, 1 << 30));
        const nextSum = nextCount <= 0 ? 0 : Math.max(0, curSum + deltaSum);
        const nextAvg = nextCount <= 0 ? 0 : nextSum / nextCount;
        tx.set(templateRef, {
            rating_sum: nextSum,
            rating_count: nextCount,
            avg_rating: nextAvg,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
});
// ── Recipe likes aggregate ─────────────────────────────────────────────
exports.onRecipeLikeWrite = functions.firestore
    .document('recipe_likes/{likeId}')
    .onWrite(async (change) => {
    const beforeExists = change.before.exists;
    const afterExists = change.after.exists;
    if (beforeExists === afterExists)
        return;
    const before = (beforeExists ? change.before.data() : undefined) ?? {};
    const after = (afterExists ? change.after.data() : undefined) ?? {};
    const recipeId = ((after.recipe_id ?? before.recipe_id) ?? '').toString().trim();
    if (recipeId.length === 0)
        return;
    const delta = afterExists && !beforeExists ? 1 : !afterExists && beforeExists ? -1 : 0;
    if (delta === 0)
        return;
    const db = admin.firestore();
    const recipeRef = db.collection('recipes').doc(recipeId);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(recipeRef);
        if (!snap.exists)
            return;
        const curRaw = snap.get('likes');
        const cur = typeof curRaw === 'number' && Number.isFinite(curRaw) ? curRaw : 0;
        const next = Math.max(0, Math.min(cur + delta, 1 << 30));
        tx.set(recipeRef, { likes: next }, { merge: true });
    });
});
// ── Recipe ratings aggregate ───────────────────────────────────────────
exports.onRecipeRatingWrite = functions.firestore
    .document('recipe_ratings/{ratingId}')
    .onWrite(async (change) => {
    const before = (change.before.exists ? change.before.data() : undefined) ?? {};
    const after = (change.after.exists ? change.after.data() : undefined) ?? {};
    const recipeId = ((after.recipe_id ?? before.recipe_id) ?? '').toString().trim();
    if (recipeId.length === 0)
        return;
    const db = admin.firestore();
    const recipeRef = db.collection('recipes').doc(recipeId);
    const ratingsSnap = await db
        .collection('recipe_ratings')
        .where('recipe_id', '==', recipeId)
        .get();
    let sum = 0;
    let count = 0;
    for (const doc of ratingsSnap.docs) {
        const raw = doc.get('rating');
        if (typeof raw !== 'number' || !Number.isFinite(raw))
            continue;
        const value = Math.min(5, Math.max(1, raw));
        sum += value;
        count += 1;
    }
    const avg = count <= 0 ? 0 : sum / count;
    await recipeRef.set({
        ratingSum: sum,
        ratingCount: count,
        ratingAvg: avg,
    }, { merge: true });
});
// ── Seed sample training data (temporary utility) ─────────────────────
exports.seedTrainingSampleData = functions.https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        res.status(405).json({ ok: false, error: 'Use POST' });
        return;
    }
    const key = (req.header('x-seed-key') ?? req.query.key ?? '').trim();
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
exports.seedAchievementsCatalog = functions.https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        res.status(405).json({ ok: false, error: 'Use POST' });
        return;
    }
    const key = (req.header('x-seed-key') ?? req.query.key ?? '').trim();
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
exports.onUserTaskReminderChanged = functions.firestore
    .document('users/{userId}/tasks/{taskId}')
    .onWrite(async (change, context) => {
    const userId = context.params.userId?.trim() ?? '';
    if (!userId)
        return;
    const after = change.after.exists ? change.after.data() : undefined;
    if (!after)
        return;
    const enabled = after.notificationEnabled === true;
    if (!enabled)
        return;
    const before = change.before.exists ? change.before.data() : undefined;
    const beforeEnabled = before?.notificationEnabled === true;
    const beforeDue = before?.dueDate;
    const afterDue = after.dueDate;
    const dueChanged = (beforeDue?.toMillis?.() ?? 0) !== (afterDue?.toMillis?.() ?? 0);
    if (beforeEnabled && !dueChanged)
        return;
    const title = (after.title ?? 'Tarea pendiente').toString().trim() || 'Tarea pendiente';
    const due = afterDue?.toDate?.();
    const dueText = due
        ? `${String(due.getDate()).padStart(2, '0')}/${String(due.getMonth() + 1).padStart(2, '0')}`
        : 'hoy';
    const tokensSnap = await admin
        .firestore()
        .collection('users')
        .doc(userId)
        .collection('tokens')
        .get();
    const tokens = tokensSnap.docs
        .map((d) => (d.get('token') ?? d.id).toString().trim())
        .filter((t) => t.length > 0);
    if (tokens.length === 0)
        return;
    const result = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
            title: 'Recordatorio de tarea',
            body: `${title} · ${dueText}`,
        },
        data: {
            type: 'task_reminder',
            taskId: context.params.taskId ?? '',
        },
    });
    const invalid = [];
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
