import '../models/weekly_program_model.dart';

class WeeklyProgramsService {
  const WeeklyProgramsService();

  List<WeeklyProgramModel> getPrograms() {
    return const [
      WeeklyProgramModel(
        id: 'beginner_fullbody_4w',
        nombre: 'Full Body Base',
        objetivo: 'Crear hábito y base general',
        nivel: 'Principiante',
        semanas: 4,
        diasPorSemana: 3,
        descripcion: '3 días/semana. Alterna fuerza ligera, cardio suave y movilidad para construir consistencia.',
        estructuraDias: [
          // Week template (Mon..Sun)
          ['fullbody_express_15', null, 'cardio_suave_14', null, 'movilidad_cadera_espalda_10', null, null],
          ['fullbody_express_15', null, 'cardio_suave_14', null, 'movilidad_cadera_espalda_10', null, null],
          ['fullbody_express_15', null, 'cardio_suave_14', null, 'movilidad_cadera_espalda_10', null, null],
          ['fullbody_express_15', null, 'cardio_suave_14', null, 'movilidad_cadera_espalda_10', null, null],
        ],
      ),
      WeeklyProgramModel(
        id: 'intermediate_strength_4w',
        nombre: 'Fuerza + Core',
        objetivo: 'Mejorar fuerza y estabilidad',
        nivel: 'Intermedio',
        semanas: 4,
        diasPorSemana: 4,
        descripcion: '4 días/semana combinando fuerza full body y core. Mantén descansos activos con movilidad.',
        estructuraDias: [
          ['fullbody_fuerza_25', 'core_estabilidad_14', null, 'movilidad_cadera_espalda_10', 'fullbody_fuerza_25', null, null],
          ['fullbody_fuerza_25', 'core_estabilidad_14', null, 'movilidad_cadera_espalda_10', 'fullbody_fuerza_25', null, null],
          ['fullbody_fuerza_25', 'core_estabilidad_14', null, 'movilidad_cadera_espalda_10', 'fullbody_fuerza_25', null, null],
          ['fullbody_fuerza_25', 'core_estabilidad_14', null, 'movilidad_cadera_espalda_10', 'fullbody_fuerza_25', null, null],
        ],
      ),
      WeeklyProgramModel(
        id: 'advanced_hiit_4w',
        nombre: 'HIIT Progresivo',
        objetivo: 'Aumentar cardio y intensidad',
        nivel: 'Avanzado',
        semanas: 4,
        diasPorSemana: 4,
        descripcion: '4 días/semana. HIIT + fuerza rápida. Ajusta si notas fatiga excesiva.',
        estructuraDias: [
          ['hiit_express_18', null, 'fullbody_fuerza_25', null, 'hiit_express_18', null, 'movilidad_cadera_espalda_10'],
          ['hiit_express_18', null, 'fullbody_fuerza_25', null, 'hiit_express_18', null, 'movilidad_cadera_espalda_10'],
          ['hiit_express_18', null, 'fullbody_fuerza_25', null, 'hiit_express_18', null, 'movilidad_cadera_espalda_10'],
          ['hiit_express_18', null, 'fullbody_fuerza_25', null, 'hiit_express_18', null, 'movilidad_cadera_espalda_10'],
        ],
      ),
    ];
  }
}
