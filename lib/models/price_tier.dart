enum PriceTier {
  economical,
  medium,
  high,
}

extension PriceTierLabel on PriceTier {
  String get label => switch (this) {
        PriceTier.economical => 'Económico',
        PriceTier.medium => 'Medio',
        PriceTier.high => 'Alto',
      };
}
