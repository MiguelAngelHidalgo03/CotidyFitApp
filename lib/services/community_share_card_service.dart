import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CommunityShareCardMetricTone { stat, narrative }

class CommunityShareCardMetric {
  const CommunityShareCardMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.columnSpan = 1,
    this.tone = CommunityShareCardMetricTone.stat,
  });

  final IconData icon;
  final String label;
  final String value;
  final int columnSpan;
  final CommunityShareCardMetricTone tone;
}

class CommunityShareCardData {
  const CommunityShareCardData({
    required this.brandName,
    required this.brandUrl,
    required this.title,
    required this.headline,
    required this.accentColor,
    required this.metrics,
    required this.motivation,
    this.logoAssetPath,
    this.notes = const <String>[],
    this.notesTitle = '',
    this.headlineLabel = '',
    this.headlineSupportingText = '',
    this.motivationLabel = 'Quedate con esto',
    this.statusBadge = '',
  });

  final String brandName;
  final String brandUrl;
  final String title;
  final String headline;
  final Color accentColor;
  final List<CommunityShareCardMetric> metrics;
  final String motivation;
  final String? logoAssetPath;
  final List<String> notes;
  final String notesTitle;
  final String headlineLabel;
  final String headlineSupportingText;
  final String motivationLabel;
  final String statusBadge;
}

class CommunityShareCardService {
  static const Size _size = Size(1080, 1920);
  static const double _horizontalPadding = 56;
  static const double _topPadding = 54;
  static const double _heroTop = 292;
  static const double _contentBottom = 1848;

  ui.Image? _cachedLogo;
  String? _cachedLogoPath;

  Future<Uint8List> renderCard(CommunityShareCardData data) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final logo = await _loadLogo(data.logoAssetPath);
    final contentWidth = _size.width - (_horizontalPadding * 2);

    _paintBackground(canvas, data.accentColor);
    _paintBrandHeader(
      canvas,
      data: data,
      logo: logo,
      x: _horizontalPadding,
      y: _topPadding,
      maxWidth: contentWidth,
    );

    final heroBottom = _paintHero(
      canvas,
      data: data,
      x: _horizontalPadding,
      y: _heroTop,
      maxWidth: contentWidth,
    );

    _paintMiddleSection(
      canvas,
      data: data,
      rect: Rect.fromLTWH(
        _horizontalPadding,
        heroBottom + 24,
        contentWidth,
        _contentBottom - heroBottom - 24,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _size.width.round(),
      _size.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<ui.Image?> _loadLogo(String? assetPath) async {
    if (assetPath == null || assetPath.trim().isEmpty) return null;
    if (_cachedLogo != null && _cachedLogoPath == assetPath) {
      return _cachedLogo;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 220,
      );
      final frame = await codec.getNextFrame();
      _cachedLogo = frame.image;
      _cachedLogoPath = assetPath;
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  void _paintBackground(Canvas canvas, Color accent) {
    final deepAccent = _shade(accent, -0.22);
    final softAccent = _shade(accent, 0.12);
    final rect = Offset.zero & _size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0E1726), Color(0xFF132238)],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            softAccent.withOpacity(0.70),
            deepAccent.withOpacity(0.96),
          ],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.82, -0.72),
          radius: 1.08,
          colors: <Color>[
            Colors.white.withOpacity(0.14),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.88, 0.68),
          radius: 0.96,
          colors: <Color>[accent.withOpacity(0.18), accent.withOpacity(0.0)],
        ).createShader(rect),
    );

    canvas.drawCircle(
      const Offset(176, 184),
      148,
      Paint()..color = Colors.white.withOpacity(0.035),
    );
    canvas.drawCircle(
      const Offset(944, 356),
      196,
      Paint()..color = accent.withOpacity(0.10),
    );
    canvas.drawCircle(
      const Offset(918, 1646),
      228,
      Paint()..color = Colors.white.withOpacity(0.028),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-140, 1510, 760, 248),
        const Radius.circular(88),
      ),
      Paint()..color = accent.withOpacity(0.05),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(606, 1116, 426, 184),
        const Radius.circular(72),
      ),
      Paint()..color = Colors.white.withOpacity(0.02),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(40, 40, _size.width - 80, _size.height - 80),
        const Radius.circular(42),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.05),
    );
  }

  void _paintBrandHeader(
    Canvas canvas, {
    required CommunityShareCardData data,
    required ui.Image? logo,
    required double x,
    required double y,
    required double maxWidth,
  }) {
    const logoRadius = 92.0;
    final center = Offset(x + logoRadius, y + logoRadius);

    canvas.drawCircle(
      center,
      logoRadius + 18,
      Paint()..color = Colors.white.withOpacity(0.12),
    );
    canvas.drawCircle(
      center,
      logoRadius + 18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(0.10),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: logoRadius)),
    );
    canvas.drawCircle(
      center,
      logoRadius,
      Paint()..color = Colors.white.withOpacity(0.18),
    );
    if (logo != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        logo.width.toDouble(),
        logo.height.toDouble(),
      );
      final dst = Rect.fromCircle(center: center, radius: logoRadius);
      canvas.drawImageRect(
        logo,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      final monoStyle = const TextStyle(
        color: Colors.white,
        fontSize: 82,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.8,
      );
      final monoHeight = _measureTextHeight(
        'CF',
        maxWidth: logoRadius * 2,
        style: monoStyle,
      );
      _paintText(
        canvas,
        'CF',
        offset: Offset(center.dx - 58, center.dy - (monoHeight / 2) - 2),
        maxWidth: logoRadius * 2,
        style: monoStyle,
      );
    }
    canvas.restore();

    final textX = x + 222;
    final textWidth = math.max(maxWidth - 222, 0.0);
    _paintText(
      canvas,
      data.brandName,
      offset: Offset(textX, y + 20),
      maxWidth: textWidth,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 74,
        height: 1.0,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.0,
      ),
    );
    _paintText(
      canvas,
      'Comparte tu progreso',
      offset: Offset(textX + 6, y + 118),
      maxWidth: textWidth - 12,
      style: TextStyle(
        color: Colors.white.withOpacity(0.76),
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  double _paintHero(
    Canvas canvas, {
    required CommunityShareCardData data,
    required double x,
    required double y,
    required double maxWidth,
  }) {
    const inset = 36.0;
    final innerWidth = maxWidth - (inset * 2);
    final badgeWidth = data.statusBadge.trim().isEmpty
        ? 0.0
        : _clampDouble(118 + (data.statusBadge.trim().length * 14.0), 196, 336);
    final titleWidth = badgeWidth > 0
        ? innerWidth - badgeWidth - 18
        : innerWidth;

    final titleStyle = TextStyle(
      color: Colors.white.withOpacity(0.78),
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: 3.0,
    );
    final labelStyle = TextStyle(
      color: Colors.white.withOpacity(0.74),
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.12,
    );
    final headlineStyle = TextStyle(
      color: Colors.white,
      fontSize: _headlineFontSize(data.headline),
      height: 1.01,
      fontWeight: FontWeight.w900,
      letterSpacing: -2.8,
    );
    final supportStyle = TextStyle(
      color: Colors.white.withOpacity(0.82),
      fontSize: 30,
      height: 1.18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    );

    final titleHeight = _measureTextHeight(
      data.title.toUpperCase(),
      maxWidth: math.max(titleWidth, 0),
      style: titleStyle,
    );
    final labelHeight = data.headlineLabel.trim().isEmpty
        ? 0.0
        : _measureTextHeight(
            data.headlineLabel,
            maxWidth: innerWidth,
            style: labelStyle,
          );
    final headlineHeight = _measureTextHeight(
      data.headline,
      maxWidth: innerWidth,
      maxLines: _headlineMaxLines(data.headline),
      style: headlineStyle,
    );
    final supportHeight = data.headlineSupportingText.trim().isEmpty
        ? 0.0
        : _measureTextHeight(
            data.headlineSupportingText,
            maxWidth: innerWidth,
            maxLines: 2,
            style: supportStyle,
          );

    final heroHeight =
        42 +
        titleHeight +
        (labelHeight > 0 ? 22 + labelHeight : 0) +
        18 +
        headlineHeight +
        (supportHeight > 0 ? 18 + supportHeight : 0) +
        40;
    final heroRect = Rect.fromLTWH(x, y, maxWidth, heroHeight);
    final heroPanel = RRect.fromRectAndRadius(
      heroRect,
      const Radius.circular(42),
    );

    canvas.drawRRect(
      heroPanel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withOpacity(0.09),
            Colors.black.withOpacity(0.16),
            data.accentColor.withOpacity(0.12),
          ],
          stops: const <double>[0.0, 0.72, 1.0],
        ).createShader(heroRect),
    );
    canvas.drawRRect(
      heroPanel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.08),
    );
    canvas.drawCircle(
      Offset(heroRect.right - 112, heroRect.top + 92),
      92,
      Paint()..color = data.accentColor.withOpacity(0.14),
    );
    canvas.drawCircle(
      Offset(heroRect.right - 60, heroRect.top + 56),
      28,
      Paint()..color = Colors.white.withOpacity(0.10),
    );

    if (badgeWidth > 0) {
      _paintBadge(
        canvas,
        text: data.statusBadge,
        accent: data.accentColor,
        rect: Rect.fromLTWH(
          heroRect.right - badgeWidth - 28,
          heroRect.top + 24,
          badgeWidth,
          58,
        ),
      );
    }

    var currentY = y + 34;
    currentY += _paintText(
      canvas,
      data.title.toUpperCase(),
      offset: Offset(x + inset, currentY),
      maxWidth: math.max(titleWidth, 0),
      style: titleStyle,
    );

    if (data.headlineLabel.trim().isNotEmpty) {
      currentY += 22;
      currentY += _paintText(
        canvas,
        data.headlineLabel,
        offset: Offset(x + inset, currentY),
        maxWidth: innerWidth,
        style: labelStyle,
      );
    }

    currentY += 18;
    currentY += _paintText(
      canvas,
      data.headline,
      offset: Offset(x + inset, currentY),
      maxWidth: innerWidth,
      maxLines: _headlineMaxLines(data.headline),
      style: headlineStyle,
    );

    if (data.headlineSupportingText.trim().isNotEmpty) {
      currentY += 18;
      currentY += _paintText(
        canvas,
        data.headlineSupportingText,
        offset: Offset(x + inset, currentY),
        maxWidth: innerWidth,
        maxLines: 2,
        style: supportStyle,
      );
    }

    return heroRect.bottom;
  }

  void _paintMiddleSection(
    Canvas canvas, {
    required CommunityShareCardData data,
    required Rect rect,
  }) {
    final metrics = data.metrics
        .where((metric) => metric.value.trim().isNotEmpty)
        .toList(growable: false);
    final noteLines = data.notes
        .where((note) => note.trim().isNotEmpty)
        .toList(growable: false);
    final rows = _buildMetricRows(metrics);
    const gap = 14.0;

    final notesHeight = noteLines.isEmpty ? 0.0 : _notesPanelHeight(noteLines);
    final availableGridHeight =
        rect.height - (noteLines.isEmpty ? 0.0 : notesHeight + gap);
    var currentY = rect.top;

    if (rows.isNotEmpty && availableGridHeight > 0) {
      final rowHeights = <double>[
        for (final row in rows) _estimateRowHeight(row, rect.width, gap: gap),
      ];
      final rowMaxHeights = <double>[
        for (final row in rows) _maxRowHeight(row),
      ];
      final totalGap = gap * math.max(rows.length - 1, 0);
      var usedHeight =
          rowHeights.fold<double>(0.0, (sum, height) => sum + height) +
          totalGap;
      var remainingHeight = math.max(availableGridHeight - usedHeight, 0.0);
      var adjustableRows = <int>[
        for (var index = 0; index < rowHeights.length; index++)
          if (rowHeights[index] < rowMaxHeights[index]) index,
      ];

      while (remainingHeight > 1 && adjustableRows.isNotEmpty) {
        final share = remainingHeight / adjustableRows.length;
        final nextAdjustableRows = <int>[];
        var distributedInPass = 0.0;

        for (final index in adjustableRows) {
          final room = rowMaxHeights[index] - rowHeights[index];
          if (room <= 0.5) continue;

          final addition = math.min(room, share);
          rowHeights[index] += addition;
          distributedInPass += addition;
          if (rowHeights[index] + 0.5 < rowMaxHeights[index]) {
            nextAdjustableRows.add(index);
          }
        }

        if (distributedInPass <= 0.5) break;
        remainingHeight -= distributedInPass;
        adjustableRows = nextAdjustableRows;
      }

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final singleCard = row.items.length == 1;
        final cardWidth = singleCard ? rect.width : (rect.width - gap) / 2;
        final safeRowHeight = rowHeights[rowIndex];

        for (var index = 0; index < row.items.length; index++) {
          final cardX = singleCard
              ? rect.left
              : rect.left + (index * (cardWidth + gap));
          _paintMetricCard(
            canvas,
            metric: row.items[index],
            accent: data.accentColor,
            rect: Rect.fromLTWH(cardX, currentY, cardWidth, safeRowHeight),
          );
        }

        currentY += safeRowHeight + gap;
      }

      currentY -= gap;
    }

    if (noteLines.isNotEmpty) {
      _paintNotesPanel(
        canvas,
        data: data,
        rect: Rect.fromLTWH(
          rect.left,
          currentY == rect.top ? rect.top : currentY + gap,
          rect.width,
          notesHeight,
        ),
        lines: noteLines,
      );
    }
  }

  void _paintMetricCard(
    Canvas canvas, {
    required CommunityShareCardMetric metric,
    required Color accent,
    required Rect rect,
  }) {
    final isNarrative = metric.tone == CommunityShareCardMetricTone.narrative;
    final labelStyle = TextStyle(
      color: Colors.white.withOpacity(0.72),
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
    final valueStyle = TextStyle(
      color: Colors.white,
      fontSize: isNarrative
          ? _narrativeFontSize(metric.value)
          : _metricValueFontSize(metric.value, width: rect.width),
      height: isNarrative ? 1.15 : 1.05,
      fontWeight: isNarrative ? FontWeight.w700 : FontWeight.w900,
      letterSpacing: isNarrative ? -0.5 : -1.0,
    );

    final card = RRect.fromRectAndRadius(rect, const Radius.circular(30));
    canvas.drawRRect(
      card,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withOpacity(isNarrative ? 0.12 : 0.10),
            Colors.black.withOpacity(0.12),
            accent.withOpacity(isNarrative ? 0.12 : 0.06),
          ],
          stops: const <double>[0.0, 0.72, 1.0],
        ).createShader(rect),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.10),
    );

    final watermarkSize = isNarrative
        ? math.min(rect.width * 0.28, 110.0)
        : math.min(rect.width * 0.34, 96.0);
    _paintIconGlyph(
      canvas,
      metric.icon,
      Offset(rect.right - watermarkSize - 24, rect.bottom - watermarkSize - 18),
      color: Colors.white.withOpacity(0.05),
      size: watermarkSize,
    );

    final iconBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left + 22, rect.top + 20, 50, 50),
      const Radius.circular(16),
    );
    canvas.drawRRect(iconBg, Paint()..color = accent.withOpacity(0.30));
    _paintIconGlyph(
      canvas,
      metric.icon,
      Offset(rect.left + 35, rect.top + 32),
      color: Colors.white,
      size: 22,
    );

    _paintText(
      canvas,
      metric.label.toUpperCase(),
      offset: Offset(rect.left + 84, rect.top + 26),
      maxWidth: rect.width - 110,
      style: labelStyle,
    );

    final maxLines = isNarrative ? 4 : 3;
    final valueHeight = _measureTextHeight(
      metric.value,
      maxWidth: rect.width - 48,
      maxLines: maxLines,
      style: valueStyle,
    );
    final minValueTop = rect.top + (isNarrative ? 82 : 74);
    final maxValueTop = rect.bottom - valueHeight - 34;
    final centeredValueTop = rect.top + ((rect.height - valueHeight) / 2);
    final valueTop = maxValueTop < minValueTop
        ? minValueTop
        : _clampDouble(centeredValueTop, minValueTop, maxValueTop);

    _paintText(
      canvas,
      metric.value,
      offset: Offset(rect.left + 24, valueTop),
      maxWidth: rect.width - 48,
      maxLines: maxLines,
      style: valueStyle,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 24,
          rect.bottom - 16,
          math.min(rect.width - 48, isNarrative ? 236 : 168),
          6,
        ),
        const Radius.circular(999),
      ),
      Paint()..color = accent.withOpacity(isNarrative ? 0.62 : 0.42),
    );
  }

  void _paintNotesPanel(
    Canvas canvas, {
    required CommunityShareCardData data,
    required Rect rect,
    required List<String> lines,
  }) {
    final panel = RRect.fromRectAndRadius(rect, const Radius.circular(32));
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withOpacity(0.06),
            data.accentColor.withOpacity(0.10),
            Colors.black.withOpacity(0.16),
          ],
          stops: const <double>[0.0, 0.36, 1.0],
        ).createShader(rect),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.08),
    );

    final title = data.notesTitle.trim().isEmpty
        ? 'DETALLES'
        : data.notesTitle.trim().toUpperCase();
    _paintText(
      canvas,
      title,
      offset: Offset(rect.left + 26, rect.top + 22),
      maxWidth: rect.width - 52,
      style: TextStyle(
        color: Colors.white.withOpacity(0.72),
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
      ),
    );

    var currentY = rect.top + 60;
    for (final line in lines) {
      final parts = line.split(' · ');
      final label = parts.first.trim();
      final value = parts.length > 1
          ? parts.skip(1).join(' · ').trim()
          : line.trim();

      final noteRect = Rect.fromLTWH(
        rect.left + 18,
        currentY - 6,
        rect.width - 36,
        76,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(noteRect, const Radius.circular(22)),
        Paint()..color = Colors.white.withOpacity(0.055),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(noteRect, const Radius.circular(22)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withOpacity(0.06),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 34, currentY + 6, 16, 16),
          const Radius.circular(5),
        ),
        Paint()..color = data.accentColor.withOpacity(0.52),
      );

      _paintText(
        canvas,
        label,
        offset: Offset(rect.left + 60, currentY - 4),
        maxWidth: rect.width - 102,
        style: TextStyle(
          color: Colors.white.withOpacity(0.74),
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      );
      _paintText(
        canvas,
        value,
        offset: Offset(rect.left + 60, currentY + 18),
        maxWidth: rect.width - 102,
        maxLines: 2,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          height: 1.16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      );

      currentY += 84;
    }
  }

  double _estimateRowHeight(
    _MetricRow row,
    double totalWidth, {
    required double gap,
  }) {
    if (row.items.isEmpty) return 0;

    if (row.items.length == 1) {
      return _estimateMetricCardHeight(row.items.first, totalWidth);
    }

    final cardWidth = (totalWidth - gap) / 2;
    return row.items
        .map((item) => _estimateMetricCardHeight(item, cardWidth))
        .fold<double>(0.0, math.max);
  }

  double _estimateMetricCardHeight(
    CommunityShareCardMetric metric,
    double width,
  ) {
    final isNarrative = metric.tone == CommunityShareCardMetricTone.narrative;
    final valueStyle = TextStyle(
      color: Colors.white,
      fontSize: isNarrative
          ? _narrativeFontSize(metric.value)
          : _metricValueFontSize(metric.value, width: width),
      height: isNarrative ? 1.15 : 1.05,
      fontWeight: isNarrative ? FontWeight.w700 : FontWeight.w900,
      letterSpacing: isNarrative ? -0.5 : -1.0,
    );
    final valueHeight = _measureTextHeight(
      metric.value,
      maxWidth: width - 48,
      maxLines: isNarrative ? 4 : 3,
      style: valueStyle,
    );
    final desiredHeight = valueHeight + (isNarrative ? 154 : 138);

    return _clampDouble(
      desiredHeight,
      isNarrative ? 254 : 218,
      isNarrative ? 372 : 294,
    );
  }

  double _maxRowHeight(_MetricRow row) {
    final hasNarrative = row.items.any(
      (item) => item.tone == CommunityShareCardMetricTone.narrative,
    );
    if (hasNarrative) return 392;
    if (row.items.length == 1) return 332;
    return 304;
  }

  List<_MetricRow> _buildMetricRows(List<CommunityShareCardMetric> metrics) {
    final rows = <_MetricRow>[];
    var current = <CommunityShareCardMetric>[];
    var units = 0;

    void flush() {
      if (current.isEmpty) return;
      rows.add(_MetricRow(List<CommunityShareCardMetric>.from(current)));
      current = <CommunityShareCardMetric>[];
      units = 0;
    }

    for (final metric in metrics) {
      final span = metric.columnSpan.clamp(1, 2);
      if (span == 2) {
        flush();
        rows.add(_MetricRow(<CommunityShareCardMetric>[metric]));
        continue;
      }

      if (units + span > 2) {
        flush();
      }

      current.add(metric);
      units += span;
      if (units >= 2) {
        flush();
      }
    }

    flush();
    return rows;
  }

  double _notesPanelHeight(List<String> lines) {
    return 86 + (lines.length * 84.0);
  }

  double _headlineFontSize(String headline) {
    final compact = headline.replaceAll(RegExp(r'\s+'), ' ').trim();
    final length = compact.length;
    final hasDigits = RegExp(r'\d').hasMatch(compact);

    if (hasDigits && length <= 9) return 158;
    if (hasDigits && length <= 14) return 142;
    if (length <= 16) return 104;
    if (length <= 28) return 84;
    return 70;
  }

  int _headlineMaxLines(String headline) {
    final compact = headline.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (RegExp(r'\d').hasMatch(compact) && compact.length <= 14) {
      return 2;
    }
    return compact.length <= 32 ? 2 : 3;
  }

  double _metricValueFontSize(String value, {required double width}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final length = compact.length;
    if (width >= 880 && length <= 22) return 76;
    if (length <= 8) return 72;
    if (length <= 16) return 62;
    if (length <= 28) return 54;
    return 46;
  }

  double _narrativeFontSize(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 60) return 46;
    if (compact.length <= 110) return 40;
    return 36;
  }

  double _badgeFontSize(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 18) return 22;
    if (compact.length <= 28) return 20;
    return 18;
  }

  void _paintBadge(
    Canvas canvas, {
    required String text,
    required Color accent,
    required Rect rect,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final badge = RRect.fromRectAndRadius(rect, const Radius.circular(999));
    canvas.drawRRect(
      badge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withOpacity(0.92),
            _shade(accent, -0.18).withOpacity(0.98),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      badge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.18),
    );

    final style = TextStyle(
      color: Colors.white,
      fontSize: _badgeFontSize(trimmed),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );
    final textHeight = _measureTextHeight(
      trimmed,
      maxWidth: rect.width - 40,
      style: style,
      maxLines: 1,
    );
    _paintText(
      canvas,
      trimmed,
      offset: Offset(
        rect.left + 20,
        rect.top + ((rect.height - textHeight) / 2) - 1,
      ),
      maxWidth: rect.width - 40,
      maxLines: 1,
      style: style,
    );
  }

  double _paintText(
    Canvas canvas,
    String text, {
    required Offset offset,
    required double maxWidth,
    required TextStyle style,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    if (text.trim().isEmpty || maxWidth <= 0) return 0;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, offset);
    return painter.height;
  }

  double _measureTextHeight(
    String text, {
    required double maxWidth,
    required TextStyle style,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    if (text.trim().isEmpty || maxWidth <= 0) return 0;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }

  void _paintIconGlyph(
    Canvas canvas,
    IconData icon,
    Offset offset, {
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          color: color,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  double _clampDouble(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = _clampDouble(hsl.lightness + amount, 0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}

class _MetricRow {
  const _MetricRow(this.items);

  final List<CommunityShareCardMetric> items;
}
