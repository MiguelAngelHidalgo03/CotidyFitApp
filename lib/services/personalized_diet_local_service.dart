import 'package:shared_preferences/shared_preferences.dart';

import '../models/personalized_diet_model.dart';

class PersonalizedDietLocalService {
  static const _kPersonalizedDietKey = 'cf_personalized_diet_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<PersonalizedDietModel?> getPersonalizedDiet() async {
    final p = await _prefs();
    final raw = p.getString(_kPersonalizedDietKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return personalizedDietFromJsonString(raw);
  }

  Future<void> setPersonalizedDiet(PersonalizedDietModel? model) async {
    final p = await _prefs();
    if (model == null) {
      await p.remove(_kPersonalizedDietKey);
      return;
    }
    await p.setString(_kPersonalizedDietKey, personalizedDietToJsonString(model));
  }
}
