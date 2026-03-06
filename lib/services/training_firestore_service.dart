import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/exercise.dart';
import '../models/training_program_detail_model.dart';
import '../models/weekly_program_model.dart';
import '../models/workout.dart';

class TrainingFirestoreService {
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  TrainingFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get currentUid => _ready ? _auth.currentUser?.uid : null;

  Future<Map<String, String>> getExerciseNameMap() async {
    if (!_ready || currentUid == null) return const {};
    final qs = await _db.collection('exercises').get();
    final out = <String, String>{};
    for (final d in qs.docs) {
      final data = d.data();
      final name = data['name'];
      if (name is String && name.trim().isNotEmpty) {
        out[d.id] = name.trim();
      }
    }
    return out;
  }

  Future<List<Workout>> getRoutines() async {
    if (!_ready || currentUid == null) return const [];

    final exerciseById = await _getExerciseDetailsMap();
    final routineSnap = await _db.collection('routines').get();
    final out = <Workout>[];

    for (final doc in routineSnap.docs) {
      final data = doc.data();
      final name = _asString(data['name']);
      if (name.isEmpty) continue;

      final exSnap = await doc.reference
          .collection('exercises')
          .orderBy('order')
          .get();

      final exercises = <Exercise>[];
      for (final exDoc in exSnap.docs) {
        final ex = exDoc.data();
        final exerciseId = _asString(ex['exerciseId']);
        final details = exerciseById[exerciseId];
        final exName = details?.name ?? exerciseId;
        final sets = _asInt(ex['sets'], fallback: 3);
        final reps = _asInt(ex['reps'], fallback: 10);
        final restSeconds = _asInt(ex['restSeconds'], fallback: 60);
        exercises.add(
          Exercise(
            name: exName,
            repsOrTime: '$sets x $reps',
            description: details?.description ?? '',
            imageUrl: _normalizeMediaUrl(details?.imageUrl),
            videoUrl: _normalizeMediaUrl(details?.videoUrl),
            variants: details?.variants ?? const [],
            muscleGroup: details?.muscleGroup ?? MuscleGroup.otros,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds > 0 ? restSeconds : null,
          ),
        );
      }

      final levelRaw = _asString(data['difficultyLevel']);
      final level = _prettyLevel(levelRaw);

      final routine = Workout(
        id: doc.id,
        name: name,
        category: _asString(data['sportCategory'], fallback: 'General'),
        durationMinutes: _asInt(data['durationMinutes'], fallback: 20),
        level: level,
        exercises: exercises,
        places: _placesFromEquipment(
          _asString(data['equipmentNeeded'], fallback: 'none'),
        ),
        goals: _goalsFromList(_asStringList(data['recommendedForGoals'])),
        difficulty: _difficultyFromLevel(levelRaw),
        equipmentNeeded: _asString(data['equipmentNeeded'], fallback: 'none'),
        sportCategory: _asString(data['sportCategory']),
        recommendedForGoals: _asStringList(data['recommendedForGoals']),
        contraindications: _asStringList(data['contraindications']),
        medicalWarnings: _asStringList(data['medicalWarnings']),
        recommendedProfileTags: _asStringList(data['recommendedProfileTags']),
      );
      out.add(routine);
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<List<Workout>> getUserGeneratedRoutines() async {
    final uid = currentUid;
    if (!_ready || uid == null) return const [];

    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('generatedRoutines')
        .get();

    final out = <Workout>[];
    for (final d in qs.docs) {
      final data = d.data();
      final name = _asString(data['name']);
      if (name.isEmpty) continue;

      final exercisesRaw = data['exercises'];
      final exercises = <Exercise>[];
      if (exercisesRaw is List) {
        for (final item in exercisesRaw) {
          if (item is! Map) continue;
          final map = item.map((k, v) => MapEntry(k.toString(), v));

          final repsOrTime = _asString(map['repsOrTime'], fallback: '10 reps');
          final parsed = _parseSetsAndReps(repsOrTime);
          final sets = _asInt(map['sets'], fallback: parsed?.sets ?? 0);
          final reps = _asInt(map['reps'], fallback: parsed?.reps ?? 0);
          final restSeconds = _asInt(map['restSeconds'], fallback: 0);
          final durationSeconds = _asInt(
            map['durationSeconds'] ?? map['duracion'],
            fallback: 0,
          );

          exercises.add(
            Exercise(
              name: _asString(map['name'], fallback: 'Ejercicio'),
              repsOrTime: repsOrTime,
              description: _asString(map['description']),
              imageUrl: _normalizeMediaUrl(_asString(map['imageUrl'])),
              videoUrl: _normalizeMediaUrl(_asString(map['videoUrl'])),
              variants: _parseVariants(map['variants']),
              muscleGroup: muscleGroupFromFirestore(
                map['muscleGroup'] ?? map['muscle_group'],
              ),
              sets: sets > 0 ? sets : null,
              reps: reps > 0 ? reps : null,
              restSeconds: restSeconds > 0 ? restSeconds : null,
              durationSeconds: durationSeconds > 0 ? durationSeconds : null,
            ),
          );
        }
      }

      out.add(
        Workout(
          id: d.id,
          name: name,
          category: _asString(data['category'], fallback: 'Programa semanal'),
          durationMinutes: _asInt(data['durationMinutes'], fallback: 25),
          level: _asString(data['level'], fallback: 'Intermedio'),
          exercises: exercises,
          places: _placesFromEquipment(
            _asString(data['equipmentNeeded'], fallback: 'none'),
          ),
          goals: _goalsFromList(_asStringList(data['recommendedForGoals'])),
          difficulty: _difficultyFromLevel(
            _asString(data['difficultyLevel'], fallback: 'intermedio'),
          ),
          equipmentNeeded: _asString(data['equipmentNeeded'], fallback: 'none'),
          sportCategory: _asString(data['sportCategory']),
          recommendedForGoals: _asStringList(data['recommendedForGoals']),
          contraindications: _asStringList(data['contraindications']),
          medicalWarnings: _asStringList(data['medicalWarnings']),
          recommendedProfileTags: _asStringList(data['recommendedProfileTags']),
        ),
      );
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<List<WeeklyProgramModel>> getWeeklyPrograms() async {
    if (!_ready || currentUid == null) return const [];
    final qs = await _db.collection('weeklyPrograms').get();
    final out = <WeeklyProgramModel>[];

    for (final d in qs.docs) {
      final map = <String, Object?>{'id': d.id, ...d.data()};
      final model = WeeklyProgramModel.fromJson(map);
      if (model != null) out.add(model);
    }
    out.sort((a, b) => a.nombre.compareTo(b.nombre));
    return out;
  }

  Future<WeeklyProgramDetailModel?> getWeeklyProgramDetail({
    required String programId,
    bool preferUserCopy = true,
  }) async {
    if (!_ready || currentUid == null) return null;

    final uid = currentUid;
    final sourceRef = _db.collection('weeklyPrograms').doc(programId);
    final sourceSnap = await sourceRef.get();
    if (!sourceSnap.exists) return null;

    final program = WeeklyProgramModel.fromJson({
      'id': sourceSnap.id,
      ...sourceSnap.data()!,
    });
    if (program == null) return null;

    final exerciseNames = await getExerciseNameMap();

    CollectionReference<Map<String, dynamic>> daysCol = sourceRef.collection(
      'days',
    );
    var isUserCopy = false;

    if (preferUserCopy && uid != null) {
      final userRef = _db
          .collection('users')
          .doc(uid)
          .collection('activePrograms')
          .doc(programId);
      final userSnap = await userRef.get();
      if (userSnap.exists) {
        daysCol = userRef.collection('days');
        isUserCopy = true;
      }
    }

    final daysSnap = await daysCol.orderBy('order').get();
    final days = <ProgramDayModel>[];
    for (final dayDoc in daysSnap.docs) {
      final day = dayDoc.data();
      final exSnap = await dayDoc.reference
          .collection('exercises')
          .orderBy('order')
          .get();
      final exercises = <ProgramDayExerciseModel>[];
      for (final exDoc in exSnap.docs) {
        final ex = exDoc.data();
        final exerciseId = _asString(ex['exerciseId']);
        exercises.add(
          ProgramDayExerciseModel(
            id: exDoc.id,
            exerciseId: exerciseId,
            exerciseName: exerciseNames[exerciseId] ?? exerciseId,
            sets: _asInt(ex['sets'], fallback: 3),
            reps: _asInt(ex['reps'], fallback: 10),
            restSeconds: _asInt(ex['restSeconds'], fallback: 60),
            order: _asInt(ex['order']),
          ),
        );
      }

      days.add(
        ProgramDayModel(
          id: dayDoc.id,
          dayName: _asString(day['dayName'], fallback: dayDoc.id),
          focus: _asString(day['focus']),
          order: _asInt(day['order']),
          exercises: exercises,
        ),
      );
    }

    return WeeklyProgramDetailModel(
      program: program,
      days: days,
      isUserSpecificCopy: isUserCopy,
    );
  }

  Future<List<MapEntry<String, String>>> getExerciseOptions() async {
    final map = await getExerciseNameMap();
    final out = <MapEntry<String, String>>[];
    for (final e in map.entries) {
      out.add(MapEntry(e.key, e.value));
    }
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  Future<Map<int, String>> buildUserWeekAssignmentsFromProgram({
    required String programId,
  }) async {
    final uid = currentUid;
    if (!_ready || uid == null) return const {};

    final detail = await getWeeklyProgramDetail(
      programId: programId,
      preferUserCopy: true,
    );
    if (detail == null) return const {};

    final assignments = <int, String>{};
    final routinesCol = _db
        .collection('users')
        .doc(uid)
        .collection('generatedRoutines');
    final exerciseById = await _getExerciseDetailsMap();

    for (final day in detail.days) {
      final dayIndex = _dayToIndex(day.dayName, day.order);
      if (dayIndex == null) continue;

      final routineId = 'gen_${programId}_${day.id}';
      assignments[dayIndex] = routineId;

      final exercises = [
        for (final ex in day.exercises)
          (() {
            final details = exerciseById[ex.exerciseId];
            return {
              'exerciseId': ex.exerciseId,
              'name': ex.exerciseName,
              'repsOrTime': '${ex.sets} x ${ex.reps}',
              'sets': ex.sets,
              'reps': ex.reps,
              'restSeconds': ex.restSeconds,
              'muscleGroup':
                  (details?.muscleGroup ?? MuscleGroup.otros).firestoreKey,
              'description': details?.description ?? '',
              'imageUrl': _normalizeMediaUrl(details?.imageUrl),
              'videoUrl': _normalizeMediaUrl(details?.videoUrl),
              'variants': [
                for (final v
                    in (details?.variants ?? const <ExerciseVariant>[]))
                  {
                    'name': v.name,
                    'description': v.description,
                    'imageUrl': _normalizeMediaUrl(v.imageUrl),
                    'videoUrl': _normalizeMediaUrl(v.videoUrl),
                  },
              ],
            };
          })(),
      ];

      await routinesCol.doc(routineId).set({
        'name': '${detail.program.nombre} · ${day.dayName}',
        'category': day.focus.trim().isEmpty ? 'Programa semanal' : day.focus,
        'durationMinutes': detail.program.durationMinutes > 0
            ? detail.program.durationMinutes
            : 25,
        'level': detail.program.nivel,
        'difficultyLevel': detail.program.nivel.toLowerCase(),
        'equipmentNeeded': detail.program.equipmentNeeded,
        'sportCategory': 'programa',
        'recommendedForGoals': [detail.program.objetivo],
        'recommendedProfileTags': detail.program.recommendedProfileTags,
        'contraindications': detail.program.contraindications,
        'medicalWarnings': detail.program.medicalWarnings,
        'programId': programId,
        'dayId': day.id,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'exercises': exercises,
      }, SetOptions(merge: true));
    }

    return assignments;
  }

  Future<void> replaceProgramExercise({
    required String programId,
    required String dayId,
    required String dayExerciseDocId,
    required String newExerciseId,
  }) async {
    final uid = currentUid;
    if (!_ready || uid == null) return;

    final userProgramRef = _db
        .collection('users')
        .doc(uid)
        .collection('activePrograms')
        .doc(programId);

    final userSnap = await userProgramRef.get();
    if (!userSnap.exists) {
      await _copyProgramToUser(programId: programId, uid: uid);
    }

    final target = userProgramRef
        .collection('days')
        .doc(dayId)
        .collection('exercises')
        .doc(dayExerciseDocId);

    await target.set({
      'exerciseId': newExerciseId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _syncGeneratedRoutineFromProgramDay(
      uid: uid,
      programId: programId,
      dayId: dayId,
    );
  }

  Future<void> _copyProgramToUser({
    required String programId,
    required String uid,
  }) async {
    final sourceRef = _db.collection('weeklyPrograms').doc(programId);
    final sourceSnap = await sourceRef.get();
    if (!sourceSnap.exists) return;

    final userProgramRef = _db
        .collection('users')
        .doc(uid)
        .collection('activePrograms')
        .doc(programId);

    await userProgramRef.set({
      ...sourceSnap.data()!,
      'sourceProgramId': programId,
      'copiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final daysSnap = await sourceRef.collection('days').get();
    for (final dayDoc in daysSnap.docs) {
      final targetDayRef = userProgramRef.collection('days').doc(dayDoc.id);
      await targetDayRef.set(dayDoc.data(), SetOptions(merge: false));

      final exSnap = await dayDoc.reference.collection('exercises').get();
      for (final exDoc in exSnap.docs) {
        await targetDayRef
            .collection('exercises')
            .doc(exDoc.id)
            .set(exDoc.data(), SetOptions(merge: false));
      }
    }
  }

  Future<void> _syncGeneratedRoutineFromProgramDay({
    required String uid,
    required String programId,
    required String dayId,
  }) async {
    final detail = await getWeeklyProgramDetail(
      programId: programId,
      preferUserCopy: true,
    );
    if (detail == null) return;

    ProgramDayModel? day;
    for (final d in detail.days) {
      if (d.id == dayId) {
        day = d;
        break;
      }
    }
    if (day == null) return;

    final exerciseById = await _getExerciseDetailsMap();

    final routineId = 'gen_${programId}_$dayId';
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('generatedRoutines')
        .doc(routineId);

    await ref.set({
      'name': '${detail.program.nombre} · ${day.dayName}',
      'category': day.focus.trim().isEmpty ? 'Programa semanal' : day.focus,
      'durationMinutes': detail.program.durationMinutes > 0
          ? detail.program.durationMinutes
          : 25,
      'level': detail.program.nivel,
      'difficultyLevel': detail.program.nivel.toLowerCase(),
      'equipmentNeeded': detail.program.equipmentNeeded,
      'sportCategory': 'programa',
      'recommendedForGoals': [detail.program.objetivo],
      'recommendedProfileTags': detail.program.recommendedProfileTags,
      'contraindications': detail.program.contraindications,
      'medicalWarnings': detail.program.medicalWarnings,
      'programId': programId,
      'dayId': dayId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'exercises': [
        for (final ex in day.exercises)
          (() {
            final details = exerciseById[ex.exerciseId];
            return {
              'exerciseId': ex.exerciseId,
              'name': ex.exerciseName,
              'repsOrTime': '${ex.sets} x ${ex.reps}',
              'sets': ex.sets,
              'reps': ex.reps,
              'restSeconds': ex.restSeconds,
              'muscleGroup':
                  (details?.muscleGroup ?? MuscleGroup.otros).firestoreKey,
              'description': details?.description ?? '',
              'imageUrl': _normalizeMediaUrl(details?.imageUrl),
              'videoUrl': _normalizeMediaUrl(details?.videoUrl),
              'variants': [
                for (final v
                    in (details?.variants ?? const <ExerciseVariant>[]))
                  {
                    'name': v.name,
                    'description': v.description,
                    'imageUrl': _normalizeMediaUrl(v.imageUrl),
                    'videoUrl': _normalizeMediaUrl(v.videoUrl),
                  },
              ],
            };
          })(),
      ],
    }, SetOptions(merge: true));
  }

  int? _dayToIndex(String dayName, int order) {
    final n = dayName.trim().toLowerCase();
    if (n.startsWith('lun')) return 0;
    if (n.startsWith('mar')) return 1;
    if (n.startsWith('mié') || n.startsWith('mie')) return 2;
    if (n.startsWith('jue')) return 3;
    if (n.startsWith('vie')) return 4;
    if (n.startsWith('sáb') || n.startsWith('sab')) return 5;
    if (n.startsWith('dom')) return 6;

    if (order >= 1 && order <= 7) return order - 1;
    return null;
  }

  Future<Map<String, _ExerciseDetails>> _getExerciseDetailsMap() async {
    if (!_ready || currentUid == null) return const {};
    final qs = await _db.collection('exercises').get();
    final out = <String, _ExerciseDetails>{};
    for (final d in qs.docs) {
      final data = d.data();
      final name = _asString(data['name']);
      if (name.isEmpty) continue;
      out[d.id] = _ExerciseDetails(
        name: name,
        description: _asString(data['description']),
        imageUrl: _asString(data['imageUrl']),
        videoUrl: _asString(data['videoUrl']),
        muscleGroup: muscleGroupFromFirestore(
          data['muscleGroup'] ?? data['muscle_group'],
        ),
        variants: _parseVariants(data['variants']),
      );
    }
    return out;
  }

  ({int sets, int reps})? _parseSetsAndReps(String repsOrTime) {
    final s = repsOrTime.trim().toLowerCase();
    if (s.isEmpty) return null;

    final mx = RegExp(r'(\d+)\s*[x×]\s*(\d+)').firstMatch(s);
    if (mx != null) {
      final sets = int.tryParse(mx.group(1) ?? '');
      final reps = int.tryParse(mx.group(2) ?? '');
      if (sets != null && reps != null && sets > 0 && reps > 0) {
        return (sets: sets, reps: reps);
      }
    }

    final n = RegExp(r'(\d+)').firstMatch(s);
    final reps = n == null ? null : int.tryParse(n.group(1) ?? '');
    if (reps != null &&
        reps > 0 &&
        !s.contains('min') &&
        !RegExp(r'\bs\b').hasMatch(s)) {
      return (sets: 1, reps: reps);
    }
    return null;
  }

  List<ExerciseVariant> _parseVariants(Object? raw) {
    if (raw is! List) return const [];
    final out = <ExerciseVariant>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final name = _asString(map['name']);
      if (name.isEmpty) continue;
      out.add(
        ExerciseVariant(
          name: name,
          description: _asString(map['description']),
          imageUrl: _normalizeMediaUrl(_asString(map['imageUrl'])),
          videoUrl: _normalizeMediaUrl(_asString(map['videoUrl'])),
        ),
      );
    }
    return out;
  }

  String? _normalizeMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final raw = url.trim();

    final fileIdMatch = RegExp(
      r'drive\.google\.com/file/d/([^/]+)',
    ).firstMatch(raw);
    if (fileIdMatch != null) {
      final fileId = fileIdMatch.group(1);
      if (fileId != null && fileId.isNotEmpty) {
        return 'https://drive.google.com/uc?export=view&id=$fileId';
      }
    }

    final openIdMatch = RegExp(r'[?&]id=([^&]+)').firstMatch(raw);
    if (raw.contains('drive.google.com') && openIdMatch != null) {
      final fileId = openIdMatch.group(1);
      if (fileId != null && fileId.isNotEmpty) {
        return 'https://drive.google.com/uc?export=view&id=$fileId';
      }
    }

    return raw;
  }

  String _asString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    final out = <String>[];
    for (final v in value) {
      if (v is String && v.trim().isNotEmpty) out.add(v.trim());
    }
    return out;
  }

  WorkoutDifficulty _difficultyFromLevel(String level) {
    switch (level.toLowerCase()) {
      case 'principiante':
        return WorkoutDifficulty.leve;
      case 'avanzado':
        return WorkoutDifficulty.experto;
      case 'intermedio':
      default:
        return WorkoutDifficulty.moderado;
    }
  }

  String _prettyLevel(String level) {
    switch (level.toLowerCase()) {
      case 'principiante':
        return 'Principiante';
      case 'avanzado':
        return 'Avanzado';
      case 'intermedio':
      default:
        return 'Intermedio';
    }
  }

  List<WorkoutPlace> _placesFromEquipment(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'gym':
        return const [WorkoutPlace.gimnasio];
      case 'casa':
        return const [
          WorkoutPlace.casaConMaterial,
          WorkoutPlace.casaSinMaterial,
        ];
      case 'parque':
        return const [WorkoutPlace.aireLibre, WorkoutPlace.parqueCalistenia];
      case 'none':
      default:
        return const [WorkoutPlace.casaSinMaterial];
    }
  }

  List<WorkoutGoal> _goalsFromList(List<String> goals) {
    final out = <WorkoutGoal>[];
    for (final g in goals) {
      final v = g.toLowerCase();
      if (v.contains('grasa')) out.add(WorkoutGoal.perderGrasa);
      if (v.contains('masa')) out.add(WorkoutGoal.ganarMasaMuscular);
      if (v.contains('ton')) out.add(WorkoutGoal.tonificar);
      if (v.contains('princip')) out.add(WorkoutGoal.principiantes);
      if (v.contains('flex')) out.add(WorkoutGoal.flexibilidad);
      if (v.contains('mov')) out.add(WorkoutGoal.movilidad);
      if (v.contains('cardio')) out.add(WorkoutGoal.cardio);
    }
    return out.toSet().toList();
  }
}

class _ExerciseDetails {
  final String name;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final MuscleGroup muscleGroup;
  final List<ExerciseVariant> variants;

  const _ExerciseDetails({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.videoUrl,
    required this.muscleGroup,
    required this.variants,
  });
}
