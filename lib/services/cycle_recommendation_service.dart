import '../models/weekly_program_model.dart';
import 'women_cycle_service.dart';

class CycleRecommendationService {
  static bool isPeriodActive(WomenCycleData? cycle, {DateTime? now}) {
    if (cycle == null) return false;
    return cycle.includes(now ?? DateTime.now());
  }

  static bool isWeeklyProgramPeriodFriendly(WeeklyProgramModel program) {
    return weeklyProgramPeriodScore(program) > 0;
  }

  static int weeklyProgramPeriodScore(WeeklyProgramModel program) {
    final tags = program.recommendedProfileTags.map(_normalize).toSet();
    final text = [
      program.nombre,
      program.descripcion,
      program.objetivo,
      ...program.recommendedProfileTags,
      ...program.periodSupportTags,
      ...program.periodBenefits,
    ].map(_normalize).join(' ');

    var score = 0;

    if (program.periodFriendly) {
      score += 6;
    }

    if (tags.any(_isExplicitPeriodTag)) {
      score += 5;
    }

    if (_containsAny(text, _periodKeywords)) {
      score += 4;
    }

    if (_containsAny(text, _supportiveKeywords)) {
      score += 2;
    }

    if (_containsAny(text, _highIntensityKeywords)) {
      score -= 2;
    }

    return score < 0 ? 0 : score;
  }

  static bool _isExplicitPeriodTag(String tag) {
    return _periodKeywords.any(tag.contains) ||
        tag.contains('period_friendly') ||
        tag.contains('periodfriendly') ||
        tag.contains('menstrual_support') ||
        tag.contains('regla') ||
        tag.contains('menstru');
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  static const List<String> _periodKeywords = [
    'regla',
    'period',
    'menstru',
    'cycle',
    'ciclo',
    'dolor',
    'colico',
    'cólico',
  ];

  static const List<String> _supportiveKeywords = [
    'movilidad',
    'mobility',
    'suave',
    'gentle',
    'low impact',
    'bajo impacto',
    'estiramiento',
    'stretch',
    'pilates',
    'yoga',
    'core ligero',
    'respiracion',
    'respiración',
    'recovery',
    'recuperacion',
    'recuperación',
  ];

  static const List<String> _highIntensityKeywords = [
    'hiit',
    'explosiv',
    'maximo',
    'máximo',
    'intenso',
    'impacto alto',
    'alto impacto',
  ];
}