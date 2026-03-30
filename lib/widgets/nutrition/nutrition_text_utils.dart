String normalizeNutritionCardText(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[\u00AD\u200B\u200C\u200D\uFEFF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return sanitized;
}
