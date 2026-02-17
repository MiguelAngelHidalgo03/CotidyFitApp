import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/cf_history_point.dart';
import '../../services/weight_service.dart';
import 'progress_section_card.dart';

class ProgressMetricsGrid extends StatelessWidget {
  const ProgressMetricsGrid({
    super.key,
    required this.last7Days,
    required this.monthAverageCf,
    required this.weight,
    required this.maxStreak,
    required this.totalWorkouts,
    required this.nutritionPercentLabel,
    required this.onAddWeight,
  });

  final List<CfHistoryPoint> last7Days;
  final int monthAverageCf;
  final WeightSummary? weight;
  final int maxStreak;
  final int totalWorkouts;
  final String nutritionPercentLabel;
  final VoidCallback onAddWeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Métricas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.18,
          children: [
            _MiniChartCard(points: last7Days),
            _MetricCard(
              title: 'CF mensual',
              value: '$monthAverageCf',
              subtitle: 'promedio',
              icon: Icons.calendar_month_outlined,
            ),
            _WeightCard(summary: weight, onAddWeight: onAddWeight),
            const _MetricCard(
              title: 'Energía prom.',
              value: '—',
              subtitle: 'sin datos',
              icon: Icons.bolt_outlined,
            ),
            _MetricCard(
              title: 'Racha máx.',
              value: '$maxStreak',
              subtitle: 'días',
              icon: Icons.local_fire_department_outlined,
            ),
            _MetricCard(
              title: 'Entrenamientos',
              value: '$totalWorkouts',
              subtitle: 'total',
              icon: Icons.fitness_center_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(Icons.restaurant_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nutrición cumplida', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      nutritionPercentLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  const _MiniChartCard({required this.points});

  final List<CfHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value.toDouble()));
    }

    return ProgressSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_outlined, size: 18, color: CFColors.primary),
              const SizedBox(width: 8),
              Text(
                'CF semanal',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    spots: spots,
                    barWidth: 3,
                    color: CFColors.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: CFColors.primary.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: CFColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.summary, required this.onAddWeight});

  final WeightSummary? summary;
  final VoidCallback onAddWeight;

  String _delta(double? v) {
    if (v == null) return '—';
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final latest = summary?.latest;

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_weight_outlined, size: 18, color: CFColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Peso', style: Theme.of(context).textTheme.bodyMedium)),
              IconButton(
                onPressed: onAddWeight,
                icon: const Icon(Icons.add_circle_outline),
                color: CFColors.primary,
                tooltip: 'Añadir peso',
              ),
            ],
          ),
          const Spacer(),
          Text(
            latest == null ? '—' : latest.weight.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            latest == null ? 'sin datos' : '${_delta(summary?.diffFromPrevious)} kg vs último',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
