import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/cf_history_point.dart';
import 'progress_section_card.dart';
import 'progress_sparkline.dart';

class ProgressConstancyCard extends StatelessWidget {
  const ProgressConstancyCard({
    super.key,
    required this.weekPoints,
    required this.monthCf,
    required this.maxStreak,
  });

  final List<CfHistoryPoint> weekPoints; // oldest -> newest
  final int monthCf;
  final int maxStreak;

  @override
  Widget build(BuildContext context) {
    final values = [for (final p in weekPoints) p.value];

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
                child: const Icon(Icons.calendar_today_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Constancia',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _TinyStat(label: 'Racha máx.', value: '$maxStreak'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'CF semanal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: CFColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          ProgressSparkline(values: values, height: 38),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.bolt_outlined,
                  title: 'CF mensual',
                  value: monthCf <= 0 ? '—' : '$monthCf',
                  subtitle: 'promedio',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatPill(
                  icon: Icons.insights_outlined,
                  title: 'Últimos 7 días',
                  value: _trendLabel(weekPoints),
                  subtitle: 'tendencia',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _trendLabel(List<CfHistoryPoint> points) {
    if (points.length < 6) return '—';
    final p = points;
    final a1 = ((p[0].value + p[1].value + p[2].value) / 3).round();
    final a2 = ((p[p.length - 3].value + p[p.length - 2].value + p[p.length - 1].value) / 3).round();
    if (a2 >= a1 + 8) return '↗';
    if (a1 >= a2 + 8) return '↘';
    return '→';
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(icon, color: CFColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
