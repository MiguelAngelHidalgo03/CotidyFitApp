import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/progress_advanced_analytics.dart';
import 'progress_section_card.dart';

class ProgressAdvancedDashboard extends StatelessWidget {
  const ProgressAdvancedDashboard({
    super.key,
    required this.analytics,
    required this.onAddWeight,
    required this.userName,
    this.currentCf,
    this.womenCycleSection,
  });

  final ProgressAdvancedAnalytics analytics;
  final VoidCallback onAddWeight;
  final String userName;
  final int? currentCf;
  final Widget? womenCycleSection;

  List<String> _profileInsights(ProgressAdvancedAnalytics analytics) {
    final weekly = analytics.insights.isNotEmpty
        ? analytics.insights.first.text
        : 'Sigue registrando para generar insights accionables.';

    final out = <String>[weekly];

    final bestMonth = analytics.advanced.bestVersionMonth.trim();
    if (bestMonth.isNotEmpty && bestMonth != '—') {
      out.add('Tu mejor mes fue $bestMonth.');
    }

    out.add(
      'Balance de vida saludable: ${analytics.advanced.healthyLifeBalanceScore}%.',
    );

    return out.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    const sectionGap = SizedBox(height: 16);
    const titleGap = SizedBox(height: 8);

    final weeklyInsight = analytics.insights.isNotEmpty
        ? analytics.insights.first.text
        : 'Sigue registrando para generar insights accionables.';

    final monthHighlight =
        'Mejor mes: ${analytics.advanced.bestVersionMonth} · Balance saludable: ${analytics.advanced.healthyLifeBalanceScore}%.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopNarrativeCard(
          userName: userName,
          mainInsight: weeklyInsight,
          monthHighlight: monthHighlight,
          cfCurrent: currentCf,
          cfAverage: analytics.general.monthlyAverageCf,
          streakBest: analytics.general.bestStreak,
          streakCurrent: analytics.general.currentStreak,
        ),
        sectionGap,
        _SectionHeader(title: 'Perspectiva según tu perfil'),
        titleGap,
        _ProfileInsightsCard(items: _profileInsights(analytics)),
        sectionGap,
        _SectionHeader(title: 'Bienestar'),
        titleGap,
        _WellbeingSummaryCard(analytics: analytics),
        sectionGap,
        _SectionHeader(title: 'Actividad Física'),
        titleGap,
        _ActivitySummaryCard(
          summary: analytics.activity,
          chartPoints: analytics.activity.stepsChart,
        ),
        sectionGap,
        _SectionHeader(title: 'Progreso de Entrenamiento'),
        titleGap,
        _TrainingSummaryCard(summary: analytics.training),
        sectionGap,
        _SectionHeader(title: 'Nutrición'),
        titleGap,
        _NutritionSummaryCard(
          summary: analytics.nutrition,
          chartPoints: analytics.nutrition.caloriesTrend,
        ),
        sectionGap,
        _SectionHeader(title: 'Objetivos'),
        titleGap,
        _GoalsSummaryCard(summary: analytics.goals),
        if (womenCycleSection != null) ...[sectionGap, womenCycleSection!],
        sectionGap,
        _SectionHeader(title: 'Peso'),
        titleGap,
        _WeightSummaryExtendedCard(
          summary: analytics.weight,
          onAddWeight: onAddWeight,
          chartPoints: analytics.weight.rawTrend,
        ),
      ],
    );
  }
}

class _TopNarrativeCard extends StatelessWidget {
  const _TopNarrativeCard({
    required this.userName,
    required this.mainInsight,
    required this.monthHighlight,
    required this.cfCurrent,
    required this.cfAverage,
    required this.streakBest,
    required this.streakCurrent,
  });

  final String userName;
  final String mainInsight;
  final String monthHighlight;
  final int? cfCurrent;
  final int cfAverage;
  final int streakBest;
  final int streakCurrent;

  @override
  Widget build(BuildContext context) {
    final cfValueText = cfCurrent == null ? '—' : '$cfCurrent';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF27426B), Color(0xFF3E669D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27426B).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Gran semana, $userName!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mainInsight,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            monthHighlight,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          _TwoColumnWrap(
            columnGap: 8,
            rowGap: 8,
            children: [
              _HeroKpiCard(label: 'Puntos CF actuales', value: cfValueText),
              _HeroKpiCard(label: 'Promedio del mes', value: '$cfAverage'),
              _HeroKpiCard(label: 'Racha mensual', value: '$streakBest días'),
              _HeroKpiCard(
                label: 'Racha de días seguidos',
                value: '$streakCurrent días',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroKpiCard extends StatelessWidget {
  const _HeroKpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInsightsCard extends StatelessWidget {
  const _ProfileInsightsCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(3).toList();
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                Expanded(
                  child: Text(
                    visible[i],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (i != visible.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _TwoColumnWrap extends StatelessWidget {
  const _TwoColumnWrap({
    required this.children,
    this.columnGap = 12,
    this.rowGap = 12,
  });

  final List<Widget> children;
  final double columnGap;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        final columns = maxWidth < 360 ? 1 : 2;
        final width = columns == 1
            ? maxWidth
            : ((maxWidth - columnGap) / 2).clamp(0.0, maxWidth);

        return Wrap(
          spacing: columnGap,
          runSpacing: rowGap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _WellbeingSummaryCard extends StatelessWidget {
  const _WellbeingSummaryCard({required this.analytics});

  final ProgressAdvancedAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final advanced = analytics.advanced;

    double monthStateAverage() {
      final parts = <double>[];
      if (advanced.monthEnergyAverage > 0) {
        parts.add(advanced.monthEnergyAverage);
      }
      if (advanced.monthMoodAverage > 0) parts.add(advanced.monthMoodAverage);
      if (advanced.monthSleepAverage > 0) parts.add(advanced.monthSleepAverage);
      if (advanced.monthStressAverage > 0) {
        parts.add(6 - advanced.monthStressAverage);
      }
      if (parts.isEmpty) return 0.0;
      return parts.reduce((a, b) => a + b) / parts.length;
    }

    String ratingDescriptor(double value, {bool inverted = false}) {
      if (value <= 0) return 'Sin datos';

      final score = inverted ? (6 - value) : value;
      if (score >= 4.2) return 'Excelente';
      if (score >= 3.5) return 'Bueno';
      if (score >= 2.8) return 'Medio';
      return 'Bajo';
    }

    String percentDescriptor(int value) {
      if (value >= 80) return 'Excelente';
      if (value >= 60) return 'Bueno';
      if (value >= 40) return 'Medio';
      return 'Bajo';
    }

    final sectionTitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: CFColors.textPrimary,
    );

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TwoColumnWrap(
            children: [
              _WellbeingHighlightTile(
                icon: Icons.favorite_border,
                title: 'Estado del mes',
                value: _fmtRating(monthStateAverage()),
                subtitle: ratingDescriptor(monthStateAverage()),
                indicator: _RatingDots(value: monthStateAverage()),
              ),
              _WellbeingHighlightTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Balance vida saludable',
                value: '${advanced.healthyLifeBalanceScore}%',
                subtitle: percentDescriptor(advanced.healthyLifeBalanceScore),
                indicator: _PercentBar(percent: advanced.healthyLifeBalanceScore),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Mejor mes', value: advanced.bestVersionMonth),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('Este mes de media:', style: sectionTitleStyle),
          const SizedBox(height: 10),
          _WellbeingMetricRow(
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: 'Estado de ánimo',
            value: _fmtRating(advanced.monthMoodAverage),
            helper: ratingDescriptor(advanced.monthMoodAverage),
            rawValue: advanced.monthMoodAverage,
          ),
          const SizedBox(height: 10),
          _WellbeingMetricRow(
            icon: Icons.bolt_outlined,
            label: 'Energía',
            value: _fmtRating(advanced.monthEnergyAverage),
            helper: ratingDescriptor(advanced.monthEnergyAverage),
            rawValue: advanced.monthEnergyAverage,
          ),
          const SizedBox(height: 10),
          _WellbeingMetricRow(
            icon: Icons.self_improvement_outlined,
            label: 'Estrés',
            value: _fmtRating(advanced.monthStressAverage),
            helper: ratingDescriptor(
              advanced.monthStressAverage,
              inverted: true,
            ),
            rawValue: advanced.monthStressAverage,
            inverted: true,
          ),
          const SizedBox(height: 10),
          _WellbeingMetricRow(
            icon: Icons.nightlight_outlined,
            label: 'Calidad del sueño',
            value: _fmtRating(advanced.monthSleepAverage),
            helper: ratingDescriptor(advanced.monthSleepAverage),
            rawValue: advanced.monthSleepAverage,
          ),
        ],
      ),
    );
  }
}

class _WellbeingHighlightTile extends StatelessWidget {
  const _WellbeingHighlightTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.indicator,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.tightFor(height: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(icon, color: CFColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: CFColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (indicator != null) ...[
                  const SizedBox(height: 8),
                  indicator!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentBar extends StatelessWidget {
  const _PercentBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: LinearProgressIndicator(
        value: (percent / 100).clamp(0.0, 1.0),
        minHeight: 7,
        color: CFColors.primary,
        backgroundColor: CFColors.softGray,
      ),
    );
  }
}

class _RatingDots extends StatelessWidget {
  const _RatingDots({required this.value, this.inverted = false});

  final double value;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final hasData = value > 0;
    final score = hasData ? (inverted ? (6 - value) : value) : 0.0;
    final clamped = score.clamp(0.0, 5.0);
    final filled = clamped.round().clamp(0, 5);

    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 14,
            height: 6,
            margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
            decoration: BoxDecoration(
              color: i < filled ? CFColors.primary : CFColors.softGray,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
          ),
      ],
    );
  }
}

class _WellbeingMetricRow extends StatelessWidget {
  const _WellbeingMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.rawValue,
    this.inverted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final double rawValue;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: CFColors.softGray),
            ),
            child: Icon(icon, color: CFColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: CFColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(helper, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                _RatingDots(value: rawValue, inverted: inverted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TrainingSummaryCard extends StatelessWidget {
  const _TrainingSummaryCard({required this.summary});

  final ProgressTrainingSummary summary;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen mensual',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KeyValue(
                  label: 'Entrenamientos',
                  value: '${summary.totalWorkouts}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KeyValue(
                  label: 'Minutos entrenados',
                  value: '${summary.totalMinutes}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TwoColumnWrap(
            children: [
              _KeyValue(label: 'Nivel estimado', value: summary.estimatedLevel),
              _KeyValue(
                label: 'Músculo más entrenado',
                value: summary.mostTrainedMuscleGroup,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _KeyValue(
            label: 'Ejercicios más repetidos',
            value: summary.mostPerformedExercises.isEmpty
                ? 'Sin datos'
                : summary.mostPerformedExercises.join(' · '),
          ),
          const SizedBox(height: 12),
          _TrendBadge(
            label: 'Tendencia semanal',
            trend: summary.weeklyTrend,
            suffix: 'entrenamientos',
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.summary,
    required this.chartPoints,
  });

  final ProgressActivitySummary summary;
  final List<ChartPoint> chartPoints;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityLevelBox(
            child: Row(
              children: [
                Expanded(
                  child: _KeyValue(
                    label: 'Pasos promedio',
                    value: '${summary.averageDailySteps}',
                  ),
                ),
                Expanded(
                  child: _KeyValue(
                    label: 'Días +8.000 pasos',
                    value: '${summary.daysOver8000}',
                  ),
                ),
                Expanded(
                  child: _KeyValue(
                    label: 'Racha de pasos',
                    value: '${summary.activeDaysStreak}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ActivityLevelBox(
            child: Row(
              children: [
                Expanded(
                  child: _KeyValue(
                    label: 'Mejor día',
                    value:
                        '${summary.bestStepDayLabel} · ${summary.bestStepDaySteps} pasos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KeyValue(
                    label: 'Distancia mensual',
                    value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KeyValue(
                    label: 'Minutos de pie',
                    value: '${summary.estimatedStandingMinutes} min',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ActivityLevelBox(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _MiniLineChart(
                key: ValueKey(
                  'steps_${chartPoints.length}_${chartPoints.isEmpty ? 'x' : chartPoints.last.label}',
                ),
                points: chartPoints,
                title: 'Pasos por día',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLevelBox extends StatelessWidget {
  const _ActivityLevelBox({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
        ],
      ),
    );
  }
}

class _NutritionSummaryCard extends StatelessWidget {
  const _NutritionSummaryCard({
    required this.summary,
    required this.chartPoints,
  });

  final ProgressNutritionSummary summary;
  final List<ChartPoint> chartPoints;

  @override
  Widget build(BuildContext context) {
    final balance = summary.weeklyCalorieBalance;
    final hasLoggedMonth =
        summary.averageMonthlyCalories > 0 ||
        summary.mostRepeatedMeal != 'Sin datos';
    final balanceText = hasLoggedMonth
        ? '${balance >= 0 ? '+' : ''}$balance kcal'
        : '—';

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _KeyValue(label: 'Balance mensual', value: balanceText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KeyValue(
                  label: 'Días objetivo cumplido',
                  value: '${summary.highProteinDays}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KeyValue(
                  label: 'Comida más repetida',
                  value: summary.mostRepeatedMeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KeyValue(
                  label: 'Promedio calórico mensual',
                  value: '${summary.averageMonthlyCalories} kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MacroLegend(distribution: summary.macroDistribution),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CFColors.background,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: CFColors.softGray),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _MiniLineChart(
                key: ValueKey(
                  'cal_${chartPoints.length}_${chartPoints.isEmpty ? 'x' : chartPoints.last.label}',
                ),
                points: chartPoints,
                title: 'Tendencia de calorías',
                titleSpacing: 10,
                detailSpacing: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsSummaryCard extends StatelessWidget {
  const _GoalsSummaryCard({required this.summary});

  final ProgressGoalsSummary summary;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _KeyValue(
                  label: 'Metas diarias',
                  value: '${summary.dailyCompletionPercent}%',
                ),
              ),
              Expanded(
                child: _KeyValue(
                  label: 'Metas semanales',
                  value: '${summary.weeklyCompletionPercent}%',
                ),
              ),
              Expanded(
                child: _KeyValue(
                  label: 'Racha semanal',
                  value: '${summary.weeklyStreak}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in summary.categoryBreakdown.entries) ...[
            _LinearPercent(label: entry.key, percent: entry.value),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 6),
          _GoalsBarsChart(data: summary.categoryBreakdown),
        ],
      ),
    );
  }
}

class _WeightSummaryExtendedCard extends StatelessWidget {
  const _WeightSummaryExtendedCard({
    required this.summary,
    required this.onAddWeight,
    required this.chartPoints,
  });

  final ProgressWeightSummaryExtended summary;
  final VoidCallback onAddWeight;
  final List<ChartPoint> chartPoints;

  @override
  Widget build(BuildContext context) {
    final monthDelta = summary.monthlyComparison;
    final currentWeightText = summary.currentWeight == null
        ? '—'
        : '${summary.currentWeight!.toStringAsFixed(1)} kg';
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Evolución de peso',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onAddWeight,
                icon: const Icon(Icons.add),
                label: const Text('Añadir peso'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CFColors.background,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: CFColors.softGray),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: CFColors.primary.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: CFColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peso actual',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentWeightText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  summary.currentWeightLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KeyValue(
                  label: 'Comparación mensual',
                  value:
                      '${monthDelta >= 0 ? '+' : ''}${monthDelta.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KeyValue(
                  label: '% vs mes pasado',
                  value:
                      '${summary.changeFromLastMonthPercent >= 0 ? '+' : ''}${summary.changeFromLastMonthPercent.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoRow(label: 'Mejor mes', value: summary.bestMonth),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CFColors.background,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: CFColors.softGray),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _MiniLineChart(
                key: ValueKey(
                  'weight_${chartPoints.length}_${chartPoints.isEmpty ? 'x' : chartPoints.last.label}_${chartPoints.isEmpty ? 0 : chartPoints.last.value.toStringAsFixed(2)}',
                ),
                points: chartPoints,
                title: 'Tendencia de peso',
                valueSuffix: ' kg',
                showLeftTitles: true,
                titleSpacing: 10,
                detailSpacing: 10,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(summary.context, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _fmtRating(double value) {
  if (value <= 0) return '—';
  return '${value.toStringAsFixed(1)} / 5';
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _LinearPercent extends StatelessWidget {
  const _LinearPercent({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              '$percent%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (percent / 100).clamp(0.0, 1.0),
          minHeight: 7,
          color: CFColors.primary,
          backgroundColor: CFColors.softGray,
        ),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({
    required this.label,
    required this.trend,
    required this.suffix,
  });

  final String label;
  final TrendMetric trend;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final up = trend.delta >= 0;
    final color = up ? Colors.green.shade700 : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            up ? Icons.trending_up : Icons.trending_down,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label · ${trend.current.toStringAsFixed(0)} $suffix (${trend.delta >= 0 ? '+' : ''}${trend.delta.toStringAsFixed(0)})',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatefulWidget {
  const _MiniLineChart({
    super.key,
    required this.points,
    required this.title,
    this.valueSuffix,
    this.showLeftTitles = false,
    this.titleSpacing = 6,
    this.detailSpacing = 6,
  });

  final List<ChartPoint> points;
  final String title;
  final String? valueSuffix;
  final bool showLeftTitles;
  final double titleSpacing;
  final double detailSpacing;

  @override
  State<_MiniLineChart> createState() => _MiniLineChartState();
}

class _MiniLineChartState extends State<_MiniLineChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _MiniLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    var changed = oldWidget.points.length != widget.points.length;
    if (!changed && widget.points.isNotEmpty && oldWidget.points.isNotEmpty) {
      final oldLast = oldWidget.points.last;
      final nextLast = widget.points.last;
      changed = oldLast.label != nextLast.label || oldLast.value != nextLast.value;
    }

    if (changed) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final title = widget.title;
    final suffix = widget.valueSuffix ?? '';
    final titleSpacing = widget.titleSpacing;
    final detailSpacing = widget.detailSpacing;

    if (points.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: CFColors.background,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: CFColors.softGray),
        ),
        alignment: Alignment.center,
        child: Text(
          '$title · sin datos',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    final values = points.map((e) => e.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.2).clamp(0.5, 10.0);

    final showLeftTitles = widget.showLeftTitles;
    final range = (maxY - minY).abs();

    double pickLeftInterval(double range) {
      if (range <= 0.0) return 1.0;
      final target = range / 3;
      const candidates = <double>[0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50];
      for (final c in candidates) {
        if (c >= target) return c;
      }
      return target;
    }

    final leftInterval = showLeftTitles ? pickLeftInterval(range) : null;
    final leftDecimals = showLeftTitles && (leftInterval ?? 0) >= 1.0 ? 0 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: titleSpacing),
        SizedBox(
          height: 130,
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              minX: 0,
              maxX: max(0, points.length - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: CFColors.softGray, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showLeftTitles,
                    reservedSize: showLeftTitles ? 38 : 0,
                    interval: leftInterval,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        value.toStringAsFixed(leftDecimals),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E2633),
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map(
                        (spot) => LineTooltipItem(
                          '${points[spot.x.round()].label}\n${spot.y.toStringAsFixed(1)}$suffix',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      .toList(),
                ),
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) return;
                  final touched = response?.lineBarSpots;
                  if (touched == null || touched.isEmpty) return;
                  final nextIndex = touched.first.x.round();
                  if (_selectedIndex != nextIndex) {
                    Feedback.forTap(context);
                  }
                  setState(() {
                    _selectedIndex = nextIndex;
                  });
                },
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: CFColors.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) {
                      if (_selectedIndex == null) return false;
                      return spot.x.round() == _selectedIndex;
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: CFColors.primary.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: detailSpacing),
        Text(
          _selectedIndex == null
              ? 'Toca un punto para ver detalle.'
              : 'Detalle: ${points[_selectedIndex!].label} · ${points[_selectedIndex!].value.toStringAsFixed(1)}$suffix',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _GoalsBarsChart extends StatefulWidget {
  const _GoalsBarsChart({required this.data});

  final Map<String, int> data;

  @override
  State<_GoalsBarsChart> createState() => _GoalsBarsChartState();
}

class _GoalsBarsChartState extends State<_GoalsBarsChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return Text(
        'Sin datos de objetivos',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final entries = data.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: CFColors.softGray, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final i = value.toInt();
                      if (i < 0 || i >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          entries[i].key,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E2633),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= entries.length) {
                      return null;
                    }
                    return BarTooltipItem(
                      '${entries[groupIndex].key}\n${entries[groupIndex].value}%',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) return;
                  final spot = response?.spot;
                  if (spot == null) return;
                  final nextIndex = spot.touchedBarGroupIndex;
                  if (_selectedIndex != nextIndex) {
                    Feedback.forTap(context);
                  }
                  setState(() {
                    _selectedIndex = nextIndex;
                  });
                },
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble().clamp(0, 100),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: _selectedIndex == i
                            ? CFColors.primary
                            : CFColors.primary.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedIndex == null
              ? 'Toca una barra para ver detalle.'
              : 'Detalle: ${entries[_selectedIndex!].key} · ${entries[_selectedIndex!].value}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.distribution});

  final Map<String, double> distribution;

  @override
  Widget build(BuildContext context) {
    final entries = distribution.entries.toList();
    return Row(
      children: [
        for (final e in entries)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CFColors.background,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: CFColors.softGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${e.value.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
