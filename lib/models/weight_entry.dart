import '../utils/date_utils.dart';

class WeightEntry {
  final DateTime date; // date only
  final double weight; // kg

  const WeightEntry({required this.date, required this.weight});

  String get dateKey => DateUtilsCF.toKey(date);

  Map<String, Object?> toJson() => {
        'dateKey': dateKey,
        'weight': weight,
      };

  static WeightEntry? fromJson(Map<String, Object?> json) {
    final dateKey = json['dateKey'];
    final weight = json['weight'];
    if (dateKey is! String) return null;
    final date = DateUtilsCF.fromKey(dateKey);
    if (date == null) return null;

    double? w;
    if (weight is num) w = weight.toDouble();
    if (w == null) return null;

    return WeightEntry(date: DateUtilsCF.dateOnly(date), weight: w);
  }
}
