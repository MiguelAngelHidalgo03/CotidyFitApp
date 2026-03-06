import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/weight_entry.dart';
import 'progress_section_card.dart';

class ProgressWeightSummaryCard extends StatelessWidget {
  const ProgressWeightSummaryCard({
    super.key,
    required this.latest,
    required this.weekDiffKg,
    required this.monthDiffKg,
    required this.last30Days,
    required this.onAdd,
  });

  final WeightEntry? latest;
  final double? weekDiffKg;
  final double? monthDiffKg;
  final List<WeightEntry> last30Days;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final w = latest?.weight;
    final weightText = w == null ? '—' : '${w.toStringAsFixed(1)} kg';

    final values = [for (final e in last30Days) e.weight];

    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(Icons.monitor_weight_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Peso',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Peso actual',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            weightText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DeltaPill(
                  label: 'Semanal',
                  deltaKg: weekDiffKg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DeltaPill(
                  label: 'Mensual',
                  deltaKg: monthDiffKg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Evolución (últimos 30 días)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: _WeightLineChart(values: values),
          ),
        ],
      ),
    );
  }
}

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: CFColors.background,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: CFColors.softGray),
        ),
        alignment: Alignment.center,
        child: Text('Añade registros para ver la gráfica', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final pad = ((max - min) * 0.15).clamp(0.3, 2.0);

    return Container(
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 6),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: (min - pad),
          maxY: (max + pad),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((max - min).abs() < 0.8) ? 0.2 : 0.5,
            getDrawingHorizontalLine: (_) => FlLine(color: CFColors.softGray, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: ((max - min).abs() < 0.8) ? 0.2 : 0.5,
                getTitlesWidget: (value, _) => Text(value.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  final last = values.length - 1;
                  String label = '';
                  if (i == 0) label = 'Hace ${last}d';
                  if (i == last ~/ 2) label = 'Mitad';
                  if (i == last) label = 'Hoy';
                  return Text(label, style: Theme.of(context).textTheme.bodySmall);
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => CFColors.textPrimary,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      'Día ${s.x.toInt() + 1}\n${s.y.toStringAsFixed(1)} kg',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: CFColors.primary,
              barWidth: 3,
              dotData: FlDotData(show: values.length <= 12),
              belowBarData: BarAreaData(show: true, color: CFColors.primary.withValues(alpha: 0.10)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.label, required this.deltaKg});

  final String label;
  final double? deltaKg;

  @override
  Widget build(BuildContext context) {
    final d = deltaKg;
    final text = d == null ? '—' : '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} kg';

    final isGood = d != null && d.abs() <= 0.4;
    final isWarn = d != null && d.abs() > 1.0;

    final (bg, border, fg) = isWarn
        ? (
            Colors.amber.withValues(alpha: 0.12),
            Colors.amber.withValues(alpha: 0.45),
            Colors.amber.shade900,
          )
        : (isGood
            ? (
                Colors.green.withValues(alpha: 0.10),
                Colors.green.withValues(alpha: 0.35),
                Colors.green.shade800,
              )
            : (
                CFColors.background,
                CFColors.softGray,
                CFColors.textSecondary,
              ));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: CFColors.textPrimary,
                  ),
            ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
          ),
        ],
      ),
    );
  }
}
