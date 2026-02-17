import 'package:shared_preferences/shared_preferences.dart';

class DietTemplateSelectionLocalService {
  static const _kSelectedTemplateIdKey = 'cf_diet_template_selected_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<String?> getSelectedTemplateId() async {
    final p = await _prefs();
    return p.getString(_kSelectedTemplateIdKey);
  }

  Future<void> setSelectedTemplateId(String? id) async {
    final p = await _prefs();
    if (id == null || id.trim().isEmpty) {
      await p.remove(_kSelectedTemplateIdKey);
      return;
    }
    await p.setString(_kSelectedTemplateIdKey, id);
  }
}
