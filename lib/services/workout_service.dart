import '../models/exercise.dart';
import '../models/workout.dart';

class WorkoutService {
  const WorkoutService();

  List<Workout> getAllWorkouts() => _mockWorkouts;

  Workout? getWorkoutById(String id) {
    try {
      return _mockWorkouts.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> getCategories() {
    final set = <String>{};
    for (final w in _mockWorkouts) {
      set.add(w.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Workout> getWorkoutsByCategory(String category) {
    final list = _mockWorkouts.where((w) => w.category == category).toList();
    list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return list;
  }

  List<Workout> getFilteredWorkouts(WorkoutFilters filters) {
    return _mockWorkouts.where((w) => w.matchesFilters(filters)).toList();
  }
}

const _mockWorkouts = <Workout>[
  Workout(
    id: 'fullbody_express_15',
    name: 'Full Body Express',
    category: 'Full Body',
    durationMinutes: 15,
    level: 'Principiante',
    places: [WorkoutPlace.casaSinMaterial, WorkoutPlace.aireLibre],
    goals: [WorkoutGoal.principiantes, WorkoutGoal.tonificar],
    difficulty: WorkoutDifficulty.leve,
    exercises: [
      Exercise(name: 'Sentadillas', repsOrTime: '12 reps'),
      Exercise(name: 'Flexiones (rodillas si hace falta)', repsOrTime: '10 reps'),
      Exercise(name: 'Plancha', repsOrTime: '30 s'),
      Exercise(name: 'Zancadas', repsOrTime: '10 reps/ lado'),
    ],
  ),
  Workout(
    id: 'fullbody_fuerza_25',
    name: 'Full Body Fuerza',
    category: 'Full Body',
    durationMinutes: 25,
    level: 'Intermedio',
    places: [WorkoutPlace.casaConMaterial, WorkoutPlace.gimnasio],
    goals: [WorkoutGoal.ganarMasaMuscular, WorkoutGoal.tonificar],
    difficulty: WorkoutDifficulty.moderado,
    exercises: [
      Exercise(name: 'Sentadilla pausa', repsOrTime: '10 reps'),
      Exercise(name: 'Puente de glúteo', repsOrTime: '14 reps'),
      Exercise(name: 'Flexiones', repsOrTime: '12 reps'),
      Exercise(name: 'Superman', repsOrTime: '12 reps'),
      Exercise(name: 'Plancha lateral', repsOrTime: '25 s/ lado'),
    ],
  ),
  Workout(
    id: 'cardio_suave_14',
    name: 'Cardio Suave',
    category: 'Cardio',
    durationMinutes: 14,
    level: 'Principiante',
    places: [WorkoutPlace.casaSinMaterial, WorkoutPlace.aireLibre],
    goals: [WorkoutGoal.cardio, WorkoutGoal.perderGrasa, WorkoutGoal.principiantes],
    difficulty: WorkoutDifficulty.leve,
    exercises: [
      Exercise(name: 'Jumping jacks', repsOrTime: '45 s'),
      Exercise(name: 'Marcha en el sitio', repsOrTime: '60 s'),
      Exercise(name: 'Mountain climbers suave', repsOrTime: '30 s'),
      Exercise(name: 'Descanso', repsOrTime: '30 s'),
    ],
  ),
  Workout(
    id: 'hiit_express_18',
    name: 'HIIT Express',
    category: 'HIIT',
    durationMinutes: 18,
    level: 'Avanzado',
    places: [WorkoutPlace.casaSinMaterial, WorkoutPlace.aireLibre],
    goals: [WorkoutGoal.perderGrasa, WorkoutGoal.cardio],
    difficulty: WorkoutDifficulty.experto,
    exercises: [
      Exercise(name: 'Burpees', repsOrTime: '30 s'),
      Exercise(name: 'Sentadillas rápidas', repsOrTime: '40 s'),
      Exercise(name: 'High knees', repsOrTime: '40 s'),
      Exercise(name: 'Descanso', repsOrTime: '20 s'),
    ],
  ),
  Workout(
    id: 'movilidad_cadera_espalda_10',
    name: 'Movilidad Cadera + Espalda',
    category: 'Movilidad',
    durationMinutes: 10,
    level: 'Principiante',
    places: [WorkoutPlace.casaSinMaterial, WorkoutPlace.casaConMaterial],
    goals: [WorkoutGoal.movilidad, WorkoutGoal.flexibilidad, WorkoutGoal.principiantes],
    difficulty: WorkoutDifficulty.leve,
    exercises: [
      Exercise(name: 'Gato-vaca', repsOrTime: '60 s'),
      Exercise(name: 'Rotación torácica', repsOrTime: '8 reps/ lado'),
      Exercise(name: 'Estiramiento flexor de cadera', repsOrTime: '45 s/ lado'),
      Exercise(name: 'Postura del niño', repsOrTime: '60 s'),
    ],
  ),
  Workout(
    id: 'core_estabilidad_14',
    name: 'Core Estabilidad',
    category: 'Core',
    durationMinutes: 14,
    level: 'Intermedio',
    places: [WorkoutPlace.casaSinMaterial, WorkoutPlace.casaConMaterial],
    goals: [WorkoutGoal.tonificar],
    difficulty: WorkoutDifficulty.moderado,
    exercises: [
      Exercise(name: 'Dead bug', repsOrTime: '10 reps/ lado'),
      Exercise(name: 'Hollow hold', repsOrTime: '25 s'),
      Exercise(name: 'Plancha', repsOrTime: '35 s'),
      Exercise(name: 'Bird-dog', repsOrTime: '10 reps/ lado'),
    ],
  ),
];
