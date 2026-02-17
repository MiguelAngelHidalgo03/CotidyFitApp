enum PrimaryGoal {
  perderGrasa,
  ganarMusculo,
  tonificar,
  rendimiento,
  salud,
}

extension PrimaryGoalX on PrimaryGoal {
  String get label {
    switch (this) {
      case PrimaryGoal.perderGrasa:
        return 'Perder grasa';
      case PrimaryGoal.ganarMusculo:
        return 'Ganar músculo';
      case PrimaryGoal.tonificar:
        return 'Tonificar';
      case PrimaryGoal.rendimiento:
        return 'Rendimiento';
      case PrimaryGoal.salud:
        return 'Salud y energía';
    }
  }
}

enum CardioStrengthPreference {
  cardio,
  fuerza,
  mixto,
}

extension CardioStrengthPreferenceX on CardioStrengthPreference {
  String get label {
    switch (this) {
      case CardioStrengthPreference.cardio:
        return 'Más cardio';
      case CardioStrengthPreference.fuerza:
        return 'Más fuerza';
      case CardioStrengthPreference.mixto:
        return 'Mixto';
    }
  }
}

class PersonalTest {
  final PrimaryGoal primaryGoal;
  final int daysPerWeek;
  final int availableMinutes;
  final CardioStrengthPreference preference;
  final String injuries;
  final String usualTrainingPlace;

  const PersonalTest({
    required this.primaryGoal,
    required this.daysPerWeek,
    required this.availableMinutes,
    required this.preference,
    required this.injuries,
    required this.usualTrainingPlace,
  });

  static PersonalTest defaults() {
    return const PersonalTest(
      primaryGoal: PrimaryGoal.salud,
      daysPerWeek: 3,
      availableMinutes: 20,
      preference: CardioStrengthPreference.mixto,
      injuries: '',
      usualTrainingPlace: 'Casa',
    );
  }

  PersonalTest copyWith({
    PrimaryGoal? primaryGoal,
    int? daysPerWeek,
    int? availableMinutes,
    CardioStrengthPreference? preference,
    String? injuries,
    String? usualTrainingPlace,
  }) {
    return PersonalTest(
      primaryGoal: primaryGoal ?? this.primaryGoal,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      preference: preference ?? this.preference,
      injuries: injuries ?? this.injuries,
      usualTrainingPlace: usualTrainingPlace ?? this.usualTrainingPlace,
    );
  }

  Map<String, Object?> toJson() => {
        'primaryGoal': primaryGoal.name,
        'daysPerWeek': daysPerWeek,
        'availableMinutes': availableMinutes,
        'preference': preference.name,
        'injuries': injuries,
        'usualTrainingPlace': usualTrainingPlace,
      };

  static PersonalTest fromJson(Map<String, Object?> json) {
    final pgRaw = json['primaryGoal'];
    final prefRaw = json['preference'];

    PrimaryGoal pg = PrimaryGoal.salud;
    for (final v in PrimaryGoal.values) {
      if (v.name == pgRaw) {
        pg = v;
        break;
      }
    }

    CardioStrengthPreference pref = CardioStrengthPreference.mixto;
    for (final v in CardioStrengthPreference.values) {
      if (v.name == prefRaw) {
        pref = v;
        break;
      }
    }

    final days = json['daysPerWeek'] is int ? json['daysPerWeek'] as int : 3;
    final minutes = json['availableMinutes'] is int ? json['availableMinutes'] as int : 20;

    final injuries = json['injuries'] is String ? json['injuries'] as String : '';
    final place = json['usualTrainingPlace'] is String ? json['usualTrainingPlace'] as String : 'Casa';

    return PersonalTest(
      primaryGoal: pg,
      daysPerWeek: days.clamp(1, 7),
      availableMinutes: minutes.clamp(5, 180),
      preference: pref,
      injuries: injuries,
      usualTrainingPlace: place,
    );
  }
}
