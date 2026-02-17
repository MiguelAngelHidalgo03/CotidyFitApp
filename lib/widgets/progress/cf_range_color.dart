import 'package:flutter/material.dart';

class CfRangeColor {
  static Color backgroundForCf(int cf) {
    final v = cf.clamp(0, 100);
    if (v <= 30) return const Color(0xFFFFE8E8); // soft red
    if (v <= 70) return const Color(0xFFFFF3D6); // soft yellow
    return const Color(0xFFE6F7EC); // soft green
  }

  static Color borderForCf(int cf) {
    final v = cf.clamp(0, 100);
    if (v <= 30) return const Color(0xFFFFC9C9);
    if (v <= 70) return const Color(0xFFFFE2A8);
    return const Color(0xFFBFE9CD);
  }
}
