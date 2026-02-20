import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/progress_week_summary.dart';
import 'progress_section_card.dart';

class ProgressHealthSummaryCard extends StatelessWidget {
  const ProgressHealthSummaryCard({super.key, required this.summary});

  final ProgressWeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final energyText = summary.energyAverage == null
        ? '—'
        : '${summary.energyAverage!.toStringAsFixed(1)} / 5';

    final hydrationText =
        '${summary.hydrationAverageLiters.toStringAsFixed(1)} L · ${summary.hydrationAveragePercent}%';

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
                child: const Icon(Icons.health_and_safety_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Salud general',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RowMetric(
            icon: Icons.event_available_outlined,
            label: 'Días activos (semana)',
            value: '${summary.activeDays}/7',
            tone: _toneForActiveDays(summary.activeDays),
          ),
          const SizedBox(height: 10),
          _RowMetric(
            icon: Icons.timer_outlined,
            label: 'Minutos entrenados',
            value: '${summary.trainedMinutes} min',
            tone: _toneForMinutes(summary.trainedMinutes),
          ),
          const SizedBox(height: 10),
          _RowMetric(
            icon: Icons.bolt_outlined,
            label: 'Energía promedio',
            value: energyText,
            tone: _toneForEnergy(summary.energyAverage),
          ),
          const SizedBox(height: 10),
          _RowMetric(
            icon: Icons.water_drop_outlined,
            label: 'Hidratación promedio',
            value: hydrationText,
            tone: _toneForHydration(summary.hydrationAveragePercent),
          ),
          const SizedBox(height: 10),
          _RowMetric(
            icon: Icons.restaurant_outlined,
            label: 'Nutrición cumplida',
            value: '${summary.nutritionCompliancePercent}%',
            tone: _toneForNutrition(summary.nutritionCompliancePercent),
          ),
        ],
      ),
    );
  }

  _MetricTone _toneForActiveDays(int days) {
    if (days >= 4) return _MetricTone.good;
    if (days >= 2) return _MetricTone.warn;
    return _MetricTone.neutral;
  }

  _MetricTone _toneForMinutes(int minutes) {
    if (minutes >= 120) return _MetricTone.good;
    if (minutes >= 60) return _MetricTone.warn;
    return _MetricTone.neutral;
  }

  _MetricTone _toneForEnergy(double? avg) {
    if (avg == null) return _MetricTone.neutral;
    if (avg >= 3.6) return _MetricTone.good;
    if (avg >= 2.8) return _MetricTone.warn;
    return _MetricTone.neutral;
  }

  _MetricTone _toneForHydration(int pct) {
    if (pct >= 85) return _MetricTone.good;
    if (pct >= 60) return _MetricTone.warn;
    return _MetricTone.neutral;
  }

  _MetricTone _toneForNutrition(int pct) {
    if (pct >= 75) return _MetricTone.good;
    if (pct >= 45) return _MetricTone.warn;
    return _MetricTone.neutral;
  }
}

enum _MetricTone { good, warn, neutral }

class _RowMetric extends StatelessWidget {
  const _RowMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (tone) {
      _MetricTone.good => (
          Colors.green.withValues(alpha: 0.10),
          Colors.green.withValues(alpha: 0.35),
          Colors.green.shade800,
        ),
      _MetricTone.warn => (
          Colors.amber.withValues(alpha: 0.12),
          Colors.amber.withValues(alpha: 0.45),
          Colors.amber.shade900,
        ),
      _MetricTone.neutral => (
          CFColors.background,
          CFColors.softGray,
          CFColors.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CFColors.textPrimary,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
