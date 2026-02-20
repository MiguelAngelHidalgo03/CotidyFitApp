import 'custom_meal_model.dart';

class DailyDataModel {
  const DailyDataModel({
    required this.dateKey,
    required this.steps,
    required this.activeMinutes,
    required this.waterLiters,
    required this.stretchesDone,
    required this.energy,
    required this.mood,
    required this.stress,
    required this.sleep,
    this.customMeals = const [],
  });

  final String dateKey;

  final int steps;
  final int activeMinutes;
  final double waterLiters;
  final bool stretchesDone;

  // 1..5 (nullable when not set)
  final int? energy;
  final int? mood;
  final int? stress;
  final int? sleep;

  final List<CustomMealEntryModel> customMeals;

  DailyDataModel copyWith({
    int? steps,
    int? activeMinutes,
    double? waterLiters,
    bool? stretchesDone,
    int? energy,
    bool clearEnergy = false,
    int? mood,
    bool clearMood = false,
    int? stress,
    bool clearStress = false,
    int? sleep,
    bool clearSleep = false,
    List<CustomMealEntryModel>? customMeals,
  }) {
    return DailyDataModel(
      dateKey: dateKey,
      steps: steps ?? this.steps,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      waterLiters: waterLiters ?? this.waterLiters,
      stretchesDone: stretchesDone ?? this.stretchesDone,
      energy: clearEnergy ? null : (energy ?? this.energy),
      mood: clearMood ? null : (mood ?? this.mood),
      stress: clearStress ? null : (stress ?? this.stress),
      sleep: clearSleep ? null : (sleep ?? this.sleep),
      customMeals: customMeals ?? this.customMeals,
    );
  }

  static DailyDataModel empty(String dateKey) {
    return DailyDataModel(
      dateKey: dateKey,
      steps: 0,
      activeMinutes: 0,
      waterLiters: 0,
      stretchesDone: false,
      energy: null,
      mood: null,
      stress: null,
      sleep: null,
      customMeals: const [],
    );
  }

  factory DailyDataModel.fromJson(Map<String, Object?> json) {
    final steps = _asInt(json['steps']) ?? 0;
    final activeMinutes = _asInt(json['activeMinutes']) ?? 0;

    // Back-compat: previous versions stored water as integer cups (250ml).
    final waterLiters = _asDouble(json['waterLiters']) ??
        ((_asInt(json['waterCups']) ?? 0) * 0.25);
    final stretchesDone = json['stretchesDone'] == true;

    return DailyDataModel(
      dateKey: (json['dateKey'] as String?) ?? '',
      steps: steps < 0 ? 0 : steps,
      activeMinutes: activeMinutes < 0 ? 0 : activeMinutes,
      waterLiters: waterLiters < 0 ? 0 : waterLiters,
      stretchesDone: stretchesDone,
      energy: _clampRating(_asInt(json['energy'])),
      mood: _clampRating(_asInt(json['mood'])),
      stress: _clampRating(_asInt(json['stress'])),
      sleep: _clampRating(_asInt(json['sleep'])),
      customMeals: CustomMealEntryModel.decodeList(json['customMeals']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'dateKey': dateKey,
      'steps': steps,
      'activeMinutes': activeMinutes,
      'waterLiters': waterLiters,
      'stretchesDone': stretchesDone,
      'energy': energy,
      'mood': mood,
      'stress': stress,
      'sleep': sleep,
      'customMeals': CustomMealEntryModel.encodeList(customMeals),
    };
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) {
      final normalized = v.trim().replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  static int? _clampRating(int? v) {
    if (v == null) return null;
    if (v < 1) return 1;
    if (v > 5) return 5;
    return v;
  }
}
