import 'weekly_program_model.dart';

class ProgramDayExerciseModel {
  const ProgramDayExerciseModel({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.order,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int reps;
  final int restSeconds;
  final int order;

  ProgramDayExerciseModel copyWith({
    String? exerciseId,
    String? exerciseName,
    int? sets,
    int? reps,
    int? restSeconds,
    int? order,
  }) {
    return ProgramDayExerciseModel(
      id: id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      order: order ?? this.order,
    );
  }
}

class ProgramDayModel {
  const ProgramDayModel({
    required this.id,
    required this.dayName,
    required this.focus,
    required this.order,
    required this.exercises,
  });

  final String id;
  final String dayName;
  final String focus;
  final int order;
  final List<ProgramDayExerciseModel> exercises;
}

class WeeklyProgramDetailModel {
  const WeeklyProgramDetailModel({
    required this.program,
    required this.days,
    required this.isUserSpecificCopy,
  });

  final WeeklyProgramModel program;
  final List<ProgramDayModel> days;
  final bool isUserSpecificCopy;
}
