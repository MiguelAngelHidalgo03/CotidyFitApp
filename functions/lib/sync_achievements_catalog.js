'use strict';

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Sync CotidyFit achievements catalog to Firestore.
//
// Source of truth: ../admin_panel/logros.txt
// Destination: achievementsCatalog/<achievementId>
//
// Usage (PowerShell) from cotidyfitapp/functions:
//   npm install
//   node lib/sync_achievements_catalog.js
//
// Preconditions:
// - You must be authenticated for admin access.
//   Option A (recommended): set GOOGLE_APPLICATION_CREDENTIALS to a service account json.
//   Option B: use Firebase CLI login with application default credentials (varies by setup).
//
// Optional env vars:
// - LOGROS_PATH: override the path to logros.txt

function normalizeKey(input) {
  const raw = String(input ?? '').trim();
  const noDiacritics = raw.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  return noDiacritics
    .toLowerCase()
    .replace(/[()]/g, '')
    .replace(/\s+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

function parseIntStrict(value, context) {
  const s = String(value ?? '').trim();
  const n = Number.parseInt(s, 10);
  if (!Number.isFinite(n)) {
    throw new Error(`Invalid int for ${context}: "${s}"`);
  }
  return n;
}

function parseDifficulty(value, context) {
  const s = String(value ?? '').trim().toLowerCase();
  if (s === 'easy' || s === 'medium' || s === 'hard') return s;
  throw new Error(`Invalid difficulty for ${context}: "${s}" (expected easy|medium|hard)`);
}

function parseLogros(text) {
  const lines = String(text ?? '').split(/\r?\n/);

  const out = [];
  let current = null;

  function finishCurrent() {
    if (!current) return;

    const id = String(current.id ?? '').trim();
    const title = String(current.title ?? '').trim();
    const description = String(current.description ?? '').trim();
    const icon = String(current.icon ?? '').trim();
    const category = String(current.category ?? '').trim();
    const conditionType = String(current.conditionType ?? '').trim();
    const conditionValue = current.conditionValue;
    const difficulty = String(current.difficulty ?? '').trim().toLowerCase();

    if (!id) throw new Error('Missing ID in an achievement block');
    if (!title) throw new Error(`Missing title for ID: ${id}`);
    if (!description) throw new Error(`Missing description for ID: ${id}`);
    if (!icon) throw new Error(`Missing icon for ID: ${id}`);
    if (!category) throw new Error(`Missing category for ID: ${id}`);
    if (!conditionType) throw new Error(`Missing conditionType for ID: ${id}`);
    if (!Number.isFinite(conditionValue)) throw new Error(`Missing target for ID: ${id}`);

    const parsedDifficulty = parseDifficulty(difficulty, `ID: ${id}`);

    out.push({
      id,
      title,
      description,
      icon,
      category,
      conditionType,
      conditionValue,
      difficulty: parsedDifficulty,
    });

    current = null;
  }

  for (const rawLine of lines) {
    const line = String(rawLine ?? '');

    const idMatch = line.match(/^\s*\d+\)\s*ID:\s*(.+?)\s*$/);
    if (idMatch) {
      finishCurrent();
      current = {
        id: idMatch[1].trim(),
        title: '',
        description: '',
        icon: '',
        category: '',
        conditionType: '',
        conditionValue: NaN,
        difficulty: '',
      };
      continue;
    }

    if (!current) continue;

    const kvMatch = line.match(/^\s*([^:]+?)\s*:\s*(.*?)\s*$/);
    if (!kvMatch) continue;

    const key = normalizeKey(kvMatch[1]);
    const value = kvMatch[2];

    switch (key) {
      case 'titulo':
        current.title = String(value ?? '').trim();
        break;
      case 'descripcion':
        current.description = String(value ?? '').trim();
        break;
      case 'icon':
        current.icon = String(value ?? '').trim();
        break;
      case 'category':
        current.category = String(value ?? '').trim();
        break;
      case 'conditiontype':
        current.conditionType = String(value ?? '').trim();
        break;
      case 'difficulty':
        current.difficulty = String(value ?? '').trim();
        break;
      case 'target':
        current.conditionValue = parseIntStrict(value, `Target for ID: ${current.id}`);
        break;
      default:
        break;
    }
  }

  finishCurrent();

  // Ensure unique IDs.
  const seen = new Set();
  for (const a of out) {
    if (seen.has(a.id)) throw new Error(`Duplicate achievement ID: ${a.id}`);
    seen.add(a.id);
  }

  return out;
}

function chunk(items, size) {
  if (size <= 0) return [items];
  const out = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

async function main() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const defaultPath = path.resolve(__dirname, '..', '..', 'admin_panel', 'logros.txt');
  const logrosPath = String(process.env.LOGROS_PATH ?? defaultPath);

  if (!fs.existsSync(logrosPath)) {
    throw new Error(`logros.txt not found at: ${logrosPath}`);
  }

  const text = fs.readFileSync(logrosPath, 'utf8');
  const achievements = parseLogros(text);

  if (achievements.length === 0) {
    throw new Error('No achievements parsed from logros.txt');
  }

  const db = admin.firestore();
  const col = db.collection('achievementsCatalog');

  const existingSnap = await col.get();
  const existingById = new Map();
  for (const doc of existingSnap.docs) {
    existingById.set(doc.id, doc.data() ?? {});
  }

  let created = 0;
  let updated = 0;
  let createdAtBackfilled = 0;

  // Batch write under 500 ops. Keep headroom.
  const batches = chunk(achievements, 400);

  for (const batchItems of batches) {
    const batch = db.batch();

    for (const a of batchItems) {
      const existing = existingById.get(a.id);
      if (existing) {
        updated++;
      } else {
        created++;
      }

      const payload = {
        title: a.title,
        description: a.description,
        icon: a.icon,
        category: a.category,
        conditionType: a.conditionType,
        conditionValue: a.conditionValue,
        difficulty: a.difficulty,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Only set createdAt when missing.
      const existingCreatedAt = existing ? existing.createdAt : null;
      if (!existingCreatedAt) {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
        if (existing) createdAtBackfilled++;
      }

      batch.set(col.doc(a.id), payload, { merge: true });
    }

    await batch.commit();
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        source: logrosPath,
        total: achievements.length,
        created,
        updated,
        createdAtBackfilled,
      },
      null,
      2
    )
  );
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
