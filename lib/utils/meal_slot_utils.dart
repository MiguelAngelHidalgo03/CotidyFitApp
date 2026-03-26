import '../models/recipe_model.dart';

String _normalizeMealSlotToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String normalizeMealSlot(String value, {String fallback = 'comida'}) {
  final normalized = _normalizeMealSlotToken(value);
  if (normalized.isEmpty) return fallback;

  if (normalized.contains('desayuno') || normalized.contains('breakfast')) {
    return 'desayuno';
  }
  if (normalized.contains('entrante') || normalized.contains('starter')) {
    return 'entrante';
  }
  if (normalized.contains('comida') ||
      normalized.contains('almuerzo') ||
      normalized.contains('lunch')) {
    return 'comida';
  }
  if (normalized.contains('post_entreno') ||
      normalized.contains('postworkout') ||
      normalized.contains('post_workout') ||
      normalized.contains('recuperacion')) {
    return 'post_entreno';
  }
  if (normalized.contains('merienda') || normalized.contains('snack')) {
    return 'merienda';
  }
  if (normalized.contains('cena') || normalized.contains('dinner')) {
    return 'cena';
  }
  if (normalized.contains('postre') || normalized.contains('dessert')) {
    return 'postre';
  }
  if (normalized.contains('tentempie') ||
      normalized.contains('colacion') ||
      normalized.contains('bocad') ||
      normalized.contains('pre_entreno') ||
      normalized.contains('preworkout') ||
      normalized.contains('pre_workout')) {
    return 'tentempie';
  }

  return fallback.isEmpty ? normalized : fallback;
}

String mealSlotLabel(String value) {
  switch (normalizeMealSlot(value, fallback: value.trim())) {
    case 'desayuno':
      return 'Desayuno';
    case 'entrante':
      return 'Entrante';
    case 'comida':
      return 'Comida';
    case 'post_entreno':
      return 'Post-entreno';
    case 'merienda':
      return 'Merienda';
    case 'cena':
      return 'Cena';
    case 'postre':
      return 'Postre';
    case 'tentempie':
      return 'Tentempié';
    default:
      return value.trim().isEmpty ? 'Comida' : value.trim();
  }
}

MealType? mealTypeFromMealSlot(String value) {
  switch (normalizeMealSlot(value, fallback: '')) {
    case 'desayuno':
      return MealType.breakfast;
    case 'entrante':
      return MealType.starter;
    case 'comida':
      return MealType.lunch;
    case 'post_entreno':
    case 'tentempie':
      return MealType.bite;
    case 'merienda':
      return MealType.snack;
    case 'cena':
      return MealType.dinner;
    case 'postre':
      return MealType.dessert;
    default:
      return null;
  }
}

int mealSlotOrder(String value) {
  switch (normalizeMealSlot(value, fallback: '')) {
    case 'desayuno':
      return 0;
    case 'entrante':
      return 1;
    case 'comida':
      return 2;
    case 'post_entreno':
      return 3;
    case 'merienda':
      return 4;
    case 'cena':
      return 5;
    case 'postre':
      return 6;
    case 'tentempie':
      return 7;
    default:
      return 99;
  }
}

int compareMealSlots(String left, String right) {
  final order = mealSlotOrder(left).compareTo(mealSlotOrder(right));
  if (order != 0) return order;
  return mealSlotLabel(left).compareTo(mealSlotLabel(right));
}

String? normalizeMealTypeValue(String value) {
  return mealTypeFromMealSlot(value)?.name;
}
