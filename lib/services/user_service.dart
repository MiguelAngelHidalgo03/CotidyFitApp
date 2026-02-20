import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'tag_generator.dart';

class UserService {
  UserService({FirebaseFirestore? db, TagGenerator? generator})
      : _db = db ?? FirebaseFirestore.instance,
        _generator = generator ?? TagGenerator();

  static final Map<String, _UidMutex> _identityMutexByUid = <String, _UidMutex>{};

  final FirebaseFirestore _db;
  final TagGenerator _generator;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _public => _db.collection('user_public');
  CollectionReference<Map<String, dynamic>> get _tags => _db.collection('user_tags');

  /// Ensures identity fields exist for the signed-in user.
  ///
  /// Data model:
  /// users/{uid}:
  ///   username
  ///   usernameNormalized
  ///   tag (6 digits)
  ///   uniqueTag (username#tag)
  ///   searchableTag (usernameNormalized#tag)
  ///
  /// Uniqueness:
  /// user_tags/{searchableTag} => { uid, uniqueTag, username, usernameNormalized, tag, createdAt, updatedAt }
  ///
  /// Writes use `merge: true` and do not overwrite unrelated fields.
  Future<void> ensureIdentityForUser(User user) async {
    if (Firebase.apps.isEmpty) return;

    final uid = user.uid;
    final mutex = _identityMutexByUid.putIfAbsent(uid, () => _UidMutex());
    await mutex.run(() async {
      final email = (user.email ?? '').trim();
      final displayName = _deriveDisplayName(email: email, firebaseDisplayName: user.displayName);

      final baseUsernameVisible = displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email.split('@').first : 'user');

      final userDoc = _users.doc(uid);
      final snap = await userDoc.get();
      final data = snap.data();

      final existingUsername = (data?['username'] as String?)?.trim() ?? '';
      final existingTag = (data?['tag'] as String?)?.trim() ?? '';
      final oldSearchableTag = (data?['searchableTag'] as String?)?.trim();

      // If username isn't set yet, try to pick the visible name from profileData.name.
      String profileName = '';
      final profileData = data?['profileData'];
      if (profileData is Map) {
        final v = profileData['name'];
        if (v != null) profileName = v.toString().trim();
      }

      final usernameVisible = (profileName.isNotEmpty
              ? profileName
              : (existingUsername.isNotEmpty ? existingUsername : baseUsernameVisible))
          .trim();
      final usernameNormalized = TagGenerator.normalize(usernameVisible);

      if (TagGenerator.isValidNumericTag6(existingTag)) {
        final uniqueTag = TagGenerator.buildUniqueTag(username: usernameVisible, tag: existingTag);
        final searchableTag = TagGenerator.buildSearchableTag(usernameNormalized: usernameNormalized, tag: existingTag);
        try {
          await _reserveAndUpsert(
            uid: uid,
            username: usernameVisible,
            usernameNormalized: usernameNormalized,
            tag: existingTag,
            uniqueTag: uniqueTag,
            searchableTag: searchableTag,
            displayName: displayName.isEmpty ? usernameVisible : displayName,
            oldSearchableTag: oldSearchableTag,
          );
          return;
        } catch (e) {
          final msg = e is StateError ? e.message : null;
          if (msg != 'tag_taken') {
            // Best-effort: ignore other failures to avoid blocking sign-in.
            return;
          }
          // Collision: fall through to generating a new tag.
        }
      }

      // Generate a unique 6-digit numeric tag (retry on collision).
      for (var attempt = 0; attempt < 25; attempt++) {
        final tag = _generator.generateNumericTag6();
        final uniqueTag = TagGenerator.buildUniqueTag(username: usernameVisible, tag: tag);
        final searchableTag = TagGenerator.buildSearchableTag(usernameNormalized: usernameNormalized, tag: tag);

        try {
          await _reserveAndUpsert(
            uid: uid,
            username: usernameVisible,
            usernameNormalized: usernameNormalized,
            tag: tag,
            uniqueTag: uniqueTag,
            searchableTag: searchableTag,
            displayName: displayName.isEmpty ? usernameVisible : displayName,
            oldSearchableTag: oldSearchableTag,
          );
          return;
        } catch (e) {
          final msg = e is StateError ? e.message : null;
          if (msg == 'tag_taken') continue;
          // Best-effort: ignore other failures to avoid blocking sign-in.
          return;
        }
      }
    });
  }

  /// Updates only the numeric tag (6 digits). Username remains stable.
  Future<void> updateTag({required String uid, required String newTag}) async {
    if (Firebase.apps.isEmpty) return;

    final mutex = _identityMutexByUid.putIfAbsent(uid, () => _UidMutex());
    await mutex.run(() async {
      final cleaned = newTag.trim();
      if (!TagGenerator.isValidNumericTag6(cleaned)) {
        throw const FormatException('Tag debe tener 6 dígitos');
      }

      final userDoc = _users.doc(uid);
      final snap = await userDoc.get();
      final data = snap.data() ?? {};

      final usernameVisible = ((data['username'] as String?)?.trim() ?? 'user').trim();
      final usernameNormalized = TagGenerator.normalize(usernameVisible);

      final oldSearchable = (data['searchableTag'] as String?)?.trim();

      final uniqueTag = TagGenerator.buildUniqueTag(username: usernameVisible, tag: cleaned);
      final searchableTag = TagGenerator.buildSearchableTag(usernameNormalized: usernameNormalized, tag: cleaned);

      if (oldSearchable != null && oldSearchable == searchableTag) return;

      try {
        await _db.runTransaction((tx) async {
        final nextRef = _tags.doc(searchableTag);
        final nextSnap = await tx.get(nextRef);
        if (nextSnap.exists) {
          final owner = (nextSnap.data()?['uid'] as String?)?.trim();
          if (owner != uid) throw StateError('tag_taken');
        }

        tx.set(
          nextRef,
          {
            'uid': uid,
            'uniqueTag': uniqueTag,
            'username': usernameVisible,
            'usernameNormalized': usernameNormalized,
            'tag': cleaned,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!nextSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (oldSearchable != null && oldSearchable.isNotEmpty && oldSearchable != searchableTag) {
          final oldRef = _tags.doc(oldSearchable);
          final oldSnap = await tx.get(oldRef);
          final oldOwner = (oldSnap.data()?['uid'] as String?)?.trim();
          if (oldSnap.exists && oldOwner == uid) {
            tx.delete(oldRef);
          }
        }

        tx.set(
          userDoc,
          {
            'username': usernameVisible,
            'usernameNormalized': usernameNormalized,
            'tag': cleaned,
            'uniqueTag': uniqueTag,
            'searchableTag': searchableTag,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(
          _public.doc(uid),
          {
            'username': usernameVisible,
            'usernameNormalized': usernameNormalized,
            'tag': cleaned,
            'uniqueTag': uniqueTag,
            'searchableTag': searchableTag,
            'visible': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        });
      } catch (e) {
        if (kIsWeb) {
          await _reserveAndUpsertNoTransaction(
            uid: uid,
            username: usernameVisible,
            usernameNormalized: usernameNormalized,
            tag: cleaned,
            uniqueTag: uniqueTag,
            searchableTag: searchableTag,
            displayName: usernameVisible,
            oldSearchableTag: oldSearchable,
          );
        } else {
          rethrow;
        }
      }
    });
  }

  /// Updates the username.
  ///
  /// Behavior:
  /// - Tries to keep the current 6-digit tag if it yields an available `username#tag`.
  /// - If taken, auto-generates a new 6-digit tag until an available one is found.
  /// - Moves the reservation doc in `user_tags/{searchableTag}` atomically.
  Future<void> updateUsername({
    required String uid,
    required String newUsername,
  }) async {
    if (Firebase.apps.isEmpty) return;

    final mutex = _identityMutexByUid.putIfAbsent(uid, () => _UidMutex());
    await mutex.run(() async {
      final raw = newUsername.trim();
      if (raw.isEmpty) {
        throw const FormatException('Username no puede estar vacío');
      }

      if (raw.contains('#')) {
        throw const FormatException('Username no puede contener #');
      }
      final usernameVisible = raw;
      final usernameNormalized = TagGenerator.normalize(usernameVisible);

      final userDoc = _users.doc(uid);
      final snap = await userDoc.get();
      final data = snap.data() ?? {};

      final existingTag = (data['tag'] as String?)?.trim() ?? '';
      final oldSearchable = (data['searchableTag'] as String?)?.trim();
      final existingUsernameRaw = (data['username'] as String?)?.trim() ?? '';
      final existingUsername = existingUsernameRaw.trim();

      // No-op if username is unchanged and tag looks valid.
      if (existingUsername == usernameVisible && TagGenerator.isValidNumericTag6(existingTag)) {
        return;
      }

      String tagCandidate;
      if (TagGenerator.isValidNumericTag6(existingTag)) {
        tagCandidate = existingTag;
      } else {
        tagCandidate = _generator.generateNumericTag6();
      }

      for (var attempt = 0; attempt < 25; attempt++) {
        final tag = attempt == 0 ? tagCandidate : _generator.generateNumericTag6();
        final uniqueTag = TagGenerator.buildUniqueTag(username: usernameVisible, tag: tag);
        final searchableTag = TagGenerator.buildSearchableTag(usernameNormalized: usernameNormalized, tag: tag);

        try {
          try {
            await _db.runTransaction((tx) async {
            final nextRef = _tags.doc(searchableTag);
            final nextSnap = await tx.get(nextRef);
            if (nextSnap.exists) {
              final owner = (nextSnap.data()?['uid'] as String?)?.trim();
              if (owner != uid) throw StateError('tag_taken');
            }

            tx.set(
              nextRef,
              {
                'uid': uid,
                'uniqueTag': uniqueTag,
                'username': usernameVisible,
                'usernameNormalized': usernameNormalized,
                'tag': tag,
                'updatedAt': FieldValue.serverTimestamp(),
                if (!nextSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );

            if (oldSearchable != null && oldSearchable.isNotEmpty && oldSearchable != searchableTag) {
              final oldRef = _tags.doc(oldSearchable);
              final oldSnap = await tx.get(oldRef);
              final oldOwner = (oldSnap.data()?['uid'] as String?)?.trim();
              if (oldSnap.exists && oldOwner == uid) {
                tx.delete(oldRef);
              }
            }

            tx.set(
              userDoc,
              {
                'username': usernameVisible,
                'usernameNormalized': usernameNormalized,
                'tag': tag,
                'uniqueTag': uniqueTag,
                'searchableTag': searchableTag,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );

            tx.set(
              _public.doc(uid),
              {
                'username': usernameVisible,
                'usernameNormalized': usernameNormalized,
                'tag': tag,
                'uniqueTag': uniqueTag,
                'searchableTag': searchableTag,
                'visible': true,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
            });
          } catch (e) {
            if (kIsWeb) {
              await _reserveAndUpsertNoTransaction(
                uid: uid,
                username: usernameVisible,
                usernameNormalized: usernameNormalized,
                tag: tag,
                uniqueTag: uniqueTag,
                searchableTag: searchableTag,
                displayName: usernameVisible,
                oldSearchableTag: oldSearchable,
              );
            } else {
              rethrow;
            }
          }

          return;
        } catch (e) {
          final msg = e is StateError ? e.message : null;
          if (msg == 'tag_taken') continue;
          rethrow;
        }
      }

      throw StateError('no_tag_available');
    });
  }

  Future<void> _reserveAndUpsert({
    required String uid,
    required String username,
    required String usernameNormalized,
    required String tag,
    required String uniqueTag,
    required String searchableTag,
    required String displayName,
    required String? oldSearchableTag,
  }) async {
    final userDoc = _users.doc(uid);
    final publicDoc = _public.doc(uid);

    try {
      await _db.runTransaction((tx) async {
        final tagDoc = _tags.doc(searchableTag);
        final tagSnap = await tx.get(tagDoc);
        if (tagSnap.exists) {
          final owner = (tagSnap.data()?['uid'] as String?)?.trim();
          if (owner != uid) throw StateError('tag_taken');
        }

        tx.set(
          tagDoc,
          {
            'uid': uid,
            'uniqueTag': uniqueTag,
            'username': username,
            'usernameNormalized': usernameNormalized,
            'tag': tag,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!tagSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (oldSearchableTag != null && oldSearchableTag.isNotEmpty && oldSearchableTag != searchableTag) {
          final oldRef = _tags.doc(oldSearchableTag);
          final oldSnap = await tx.get(oldRef);
          final oldOwner = (oldSnap.data()?['uid'] as String?)?.trim();
          if (oldSnap.exists && oldOwner == uid) {
            tx.delete(oldRef);
          }
        }

        tx.set(
          userDoc,
          {
            'username': username,
            'usernameNormalized': usernameNormalized,
            'tag': tag,
            'uniqueTag': uniqueTag,
            'searchableTag': searchableTag,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(
          publicDoc,
          {
            'displayName': displayName,
            'username': username,
            'usernameNormalized': usernameNormalized,
            'tag': tag,
            'uniqueTag': uniqueTag,
            'searchableTag': searchableTag,
            'visible': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      if (!kIsWeb) rethrow;
      await _reserveAndUpsertNoTransaction(
        uid: uid,
        username: username,
        usernameNormalized: usernameNormalized,
        tag: tag,
        uniqueTag: uniqueTag,
        searchableTag: searchableTag,
        displayName: displayName,
        oldSearchableTag: oldSearchableTag,
      );
    }
  }

  Future<void> _reserveAndUpsertNoTransaction({
    required String uid,
    required String username,
    required String usernameNormalized,
    required String tag,
    required String uniqueTag,
    required String searchableTag,
    required String displayName,
    required String? oldSearchableTag,
  }) async {
    final tagRef = _tags.doc(searchableTag);

    // Reserve the unique key.
    try {
      await tagRef.set({
        'uid': uid,
        'uniqueTag': uniqueTag,
        'username': username,
        'usernameNormalized': usernameNormalized,
        'tag': tag,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      final code = e.code.toLowerCase();
      final permissionDenied = code == 'permission-denied' || code == 'permission_denied';
      if (!permissionDenied) rethrow;

      // If the doc exists and belongs to another user, treat as collision.
      final snap = await tagRef.get();
      final owner = (snap.data()?['uid'] as String?)?.trim();
      if (snap.exists && owner != uid) throw StateError('tag_taken');
      rethrow;
    }

    // Upsert user docs.
    await _users.doc(uid).set(
      {
        'username': username,
        'usernameNormalized': usernameNormalized,
        'tag': tag,
        'uniqueTag': uniqueTag,
        'searchableTag': searchableTag,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _public.doc(uid).set(
      {
        'displayName': displayName,
        'username': username,
        'usernameNormalized': usernameNormalized,
        'tag': tag,
        'uniqueTag': uniqueTag,
        'searchableTag': searchableTag,
        'visible': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Best-effort cleanup of previous reservation.
    if (oldSearchableTag != null && oldSearchableTag.isNotEmpty && oldSearchableTag != searchableTag) {
      try {
        final oldRef = _tags.doc(oldSearchableTag);
        final oldSnap = await oldRef.get();
        final owner = (oldSnap.data()?['uid'] as String?)?.trim();
        if (oldSnap.exists && owner == uid) {
          await oldRef.delete();
        }
      } catch (_) {
        // ignore
      }
    }
  }

  String _deriveDisplayName({required String email, required String? firebaseDisplayName}) {
    final raw = (firebaseDisplayName ?? '').trim();
    if (raw.isNotEmpty) return raw;
    final at = email.indexOf('@');
    if (at <= 0) return '';
    return email.substring(0, at).trim();
  }
}

class _UidMutex {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = previous.whenComplete(() => completer.future);

    return previous.then((_) => action()).whenComplete(() {
      if (!completer.isCompleted) completer.complete();
    });
  }
}
