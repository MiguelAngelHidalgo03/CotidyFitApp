import '../models/diet_template_model.dart';

abstract class DietTemplatesRepository {
  Future<List<DietTemplateModel>> getTemplates();
  Future<DietTemplateModel?> getTemplateById(String id);
}
