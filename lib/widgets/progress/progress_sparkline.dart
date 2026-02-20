import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ProgressSparkline extends StatelessWidget {
  const ProgressSparkline({
    super.key,
    required this.values,
    this.height = 34,
    this.lineColor,
    this.fill = true,
  });

  final List<num> values;
  final double height;
  final Color? lineColor;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: CFColors.primary.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: CFColors.softGray),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          lineColor: lineColor ?? CFColors.primary,
          fill: fill,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fill,
  });

  final List<num> values;
  final Color lineColor;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final v = values.map((e) => e.toDouble()).toList(growable: false);

    var minV = v.first;
    var maxV = v.first;
    for (final x in v) {
      minV = math.min(minV, x);
      maxV = math.max(maxV, x);
    }

    final span = (maxV - minV).abs();
    final safeSpan = span < 0.0001 ? 1.0 : span;

    const pad = 3.0;
    final w = size.width;
    final h = size.height;

    final dx = (w - pad * 2) / (v.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < v.length; i++) {
      final t = (v[i] - minV) / safeSpan;
      final x = pad + dx * i;
      final y = (h - pad) - (t * (h - pad * 2));
      points.add(Offset(x, y));
    }

    final bgPaint = Paint()..color = CFColors.primary.withValues(alpha: 0.06);
    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(bgRRect, bgPaint);

    final borderPaint = Paint()
      ..color = CFColors.softGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(bgRRect, borderPaint);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, h - pad)
        ..lineTo(points.first.dx, h - pad)
        ..close();

      final fillPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(points.last, 2.6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.fill != fill ||
        !_listEquals(oldDelegate.values, values);
  }

  bool _listEquals(List<num> a, List<num> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
