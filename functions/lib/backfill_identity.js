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
const admin = __importStar(require("firebase-admin"));
// Backfill identity for existing users.
//
// Usage (PowerShell) from functions/:
//   npm run build; node lib/backfill_identity.js
//
// Preconditions:
// - You must be authenticated for admin access.
//   Option A (recommended): set GOOGLE_APPLICATION_CREDENTIALS to a service account json.
//   Option B: use Firebase CLI login with application default credentials (varies by setup).
function normalizeUsername(input) {
    const lower = input.trim().toLowerCase();
    const cleaned = lower.replace(/[^a-z0-9_]/g, '_');
    const squashed = cleaned.replace(/_+/g, '_');
    const trimmed = squashed.replace(/^_+|_+$/g, '');
    const out = trimmed.length === 0 ? 'user' : trimmed;
    return out.length > 16 ? out.substring(0, 16) : out;
}
function isValidNumericTag6(input) {
    return /^\d{6}$/.test((input ?? '').trim());
}
function generateNumericTag6() {
    const n = Math.floor(Math.random() * 1000000);
    return String(n).padStart(6, '0');
}
function buildUniqueTag(username, tag) {
    return `${normalizeUsername(username)}#${tag.trim()}`;
}
function buildSearchableTag(uniqueTag) {
    return uniqueTag.trim().toLowerCase();
}
function deriveUsernameFromUserDoc(data) {
    const usernameRaw = String(data?.username ?? '').trim();
    if (usernameRaw)
        return normalizeUsername(usernameRaw);
    // fallbacks: displayName, name, email prefix
    const displayName = String(data?.displayName ?? '').trim();
    if (displayName)
        return normalizeUsername(displayName);
    const profileName = String(data?.profileData?.name ?? data?.name ?? '').trim();
    if (profileName)
        return normalizeUsername(profileName);
    const email = String(data?.email ?? '').trim();
    const at = email.indexOf('@');
    if (at > 0)
        return normalizeUsername(email.substring(0, at));
    return 'user';
}
async function reserveAndUpsertIdentity(params) {
    const db = admin.firestore();
    const users = db.collection('users');
    const publics = db.collection('user_public');
    const tags = db.collection('user_tags');
    await db.runTransaction(async (tx) => {
        const userDoc = users.doc(params.uid);
        const publicDoc = publics.doc(params.uid);
        const tagDoc = tags.doc(params.searchableTag);
        const tagSnap = await tx.get(tagDoc);
        if (tagSnap.exists) {
            const owner = String(tagSnap.data()?.uid ?? '').trim();
            if (owner && owner !== params.uid) {
                throw new Error('tag_taken');
            }
        }
        tx.set(tagDoc, {
            uid: params.uid,
            uniqueTag: params.uniqueTag,
            username: params.username,
            tag: params.tag,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(tagSnap.exists ? {} : { createdAt: admin.firestore.FieldValue.serverTimestamp() }),
        }, { merge: true });
        if (params.deleteOldSearchableTag && params.deleteOldSearchableTag !== params.searchableTag) {
            const oldRef = tags.doc(params.deleteOldSearchableTag);
            const oldSnap = await tx.get(oldRef);
            const oldOwner = String(oldSnap.data()?.uid ?? '').trim();
            if (oldSnap.exists && oldOwner === params.uid) {
                tx.delete(oldRef);
            }
        }
        tx.set(userDoc, {
            username: params.username,
            tag: params.tag,
            uniqueTag: params.uniqueTag,
            searchableTag: params.searchableTag,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.set(publicDoc, {
            username: params.username,
            tag: params.tag,
            uniqueTag: params.uniqueTag,
            searchableTag: params.searchableTag,
            visible: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
}
async function main() {
    if (admin.apps.length === 0) {
        admin.initializeApp();
    }
    const db = admin.firestore();
    const usersSnap = await db.collection('users').get();
    let processed = 0;
    let updated = 0;
    let skipped = 0;
    let failed = 0;
    for (const doc of usersSnap.docs) {
        processed++;
        const uid = doc.id;
        const data = doc.data() ?? {};
        const existingTag = String(data.tag ?? '').trim();
        const existingUsername = String(data.username ?? '').trim();
        const existingSearchable = String(data.searchableTag ?? '').trim();
        if (isValidNumericTag6(existingTag) && existingUsername && existingSearchable) {
            skipped++;
            continue;
        }
        const username = deriveUsernameFromUserDoc(data);
        // Try keep existing tag if it is valid.
        const firstTag = isValidNumericTag6(existingTag) ? existingTag : generateNumericTag6();
        let success = false;
        for (let attempt = 0; attempt < 25; attempt++) {
            const tag = attempt === 0 ? firstTag : generateNumericTag6();
            const uniqueTag = buildUniqueTag(username, tag);
            const searchableTag = buildSearchableTag(uniqueTag);
            try {
                await reserveAndUpsertIdentity({
                    uid,
                    username,
                    tag,
                    uniqueTag,
                    searchableTag,
                    deleteOldSearchableTag: existingSearchable || null,
                });
                updated++;
                success = true;
                break;
            }
            catch (e) {
                const msg = String(e?.message ?? e);
                if (msg.includes('tag_taken')) {
                    continue;
                }
                failed++;
                console.error(`[${uid}] failed: ${msg}`);
                break;
            }
        }
        if (!success) {
            // already counted as failed where relevant
            if (failed === 0)
                failed++;
        }
    }
    console.log(JSON.stringify({
        processed,
        updated,
        skipped,
        failed,
    }, null, 2));
}
main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
