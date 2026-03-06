import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum TimeRange { week, month }

class ProgressData {
  final String userName;
  final int currentCFIndex;
  final int globalStreak;
  final String weeklyInsight;
  final List<Map<String, dynamic>> consistencyData;
  final List<Map<String, dynamic>> nutritionData;
  final List<Map<String, dynamic>> weightData;
  final List<Map<String, dynamic>> sleepData;
  final List<Map<String, dynamic>> moodData;
  final List<Map<String, dynamic>> unlockedAchievements;
  final List<Map<String, dynamic>> upcomingAchievements;
  final String smartInsight;

  const ProgressData({
    required this.userName,
    required this.currentCFIndex,
    required this.globalStreak,
    required this.weeklyInsight,
    required this.consistencyData,
    required this.nutritionData,
    required this.weightData,
    required this.sleepData,
    required this.moodData,
    required this.unlockedAchievements,
    required this.upcomingAchievements,
    required this.smartInsight,
  });
}

const ProgressData initialProgressData = ProgressData(
  userName: 'Alex',
  currentCFIndex: 75,
  globalStreak: 15,
  weeklyInsight:
      '¡Gran Semana, Alex! Has superado tu objetivo de pasos en un 15%. ¡Sigue así!',
  consistencyData: [
    {'date': '2026-02-22', 'value': 80},
    {'date': '2026-02-23', 'value': 90},
    {'date': '2026-02-24', 'value': 70},
    {'date': '2026-02-25', 'value': 85},
    {'date': '2026-02-26', 'value': 95},
    {'date': '2026-02-27', 'value': 80},
    {'date': '2026-02-28', 'value': 90},
  ],
  nutritionData: [
    {'date': '2026-02-22', 'value': 70},
    {'date': '2026-02-23', 'value': 75},
    {'date': '2026-02-24', 'value': 65},
    {'date': '2026-02-25', 'value': 80},
    {'date': '2026-02-26', 'value': 85},
    {'date': '2026-02-27', 'value': 70},
    {'date': '2026-02-28', 'value': 75},
  ],
  weightData: [
    {'date': '2026-02-22', 'value': 75.5},
    {'date': '2026-02-23', 'value': 75.4},
    {'date': '2026-02-24', 'value': 75.3},
    {'date': '2026-02-25', 'value': 75.2},
    {'date': '2026-02-26', 'value': 75.1},
    {'date': '2026-02-27', 'value': 75.0},
    {'date': '2026-02-28', 'value': 74.9},
  ],
  sleepData: [
    {'date': '2026-02-22', 'value': 7.5},
    {'date': '2026-02-23', 'value': 8.0},
    {'date': '2026-02-24', 'value': 6.5},
    {'date': '2026-02-25', 'value': 7.0},
    {'date': '2026-02-26', 'value': 7.5},
    {'date': '2026-02-27', 'value': 8.5},
    {'date': '2026-02-28', 'value': 7.0},
  ],
  moodData: [
    {'date': '2026-02-22', 'value': 4},
    {'date': '2026-02-23', 'value': 5},
    {'date': '2026-02-24', 'value': 3},
    {'date': '2026-02-25', 'value': 4},
    {'date': '2026-02-26', 'value': 5},
    {'date': '2026-02-27', 'value': 4},
    {'date': '2026-02-28', 'value': 4},
  ],
  unlockedAchievements: [
    {'id': 'a1', 'name': 'Maratón de Agua', 'date': '2026-02-25'},
    {'id': 'a2', 'name': 'Madrugador', 'date': '2026-02-20'},
  ],
  upcomingAchievements: [
    {'id': 'a3', 'name': 'Caminante Urbano', 'progress': 70},
    {'id': 'a4', 'name': 'Maestro de la Calma', 'progress': 40},
  ],
  smartInsight: 'Tu sueño mejoró un 10% los días que meditaste.',
);

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressData progressData = initialProgressData;
  TimeRange selectedRange = TimeRange.week;
  final Map<String, int?> selectedMetricPoints = {
    'consistency': null,
    'nutrition': null,
    'weight': null,
    'sleep': null,
    'mood': null,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopSummary(colorScheme),
            const SizedBox(height: 16),
            _buildRangeSelector(),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Constancia',
              icon: Icons.track_changes_rounded,
              insight: _metricInsight(_dataFor(selectedRange, progressData.consistencyData), 'constancia'),
              child: _MetricChart(
                metricKey: 'consistency',
                color: colorScheme.primary,
                points: _toSpots(_dataFor(selectedRange, progressData.consistencyData)),
                labels: _labelsFor(_dataFor(selectedRange, progressData.consistencyData)),
                selectedIndex: selectedMetricPoints['consistency'],
                minY: 0,
                maxY: 100,
                suffix: '%',
                onTouched: _onPointTouched,
              ),
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Nutrición',
              icon: Icons.restaurant_menu_rounded,
              insight: _metricInsight(_dataFor(selectedRange, progressData.nutritionData), 'nutrición'),
              child: _MetricChart(
                metricKey: 'nutrition',
                color: Colors.green.shade600,
                points: _toSpots(_dataFor(selectedRange, progressData.nutritionData)),
                labels: _labelsFor(_dataFor(selectedRange, progressData.nutritionData)),
                selectedIndex: selectedMetricPoints['nutrition'],
                minY: 0,
                maxY: 100,
                suffix: '%',
                onTouched: _onPointTouched,
              ),
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Peso',
              icon: Icons.monitor_weight_outlined,
              insight: _weightInsight(_dataFor(selectedRange, progressData.weightData)),
              child: _MetricChart(
                metricKey: 'weight',
                color: Colors.orange.shade700,
                points: _toSpots(_dataFor(selectedRange, progressData.weightData)),
                labels: _labelsFor(_dataFor(selectedRange, progressData.weightData)),
                selectedIndex: selectedMetricPoints['weight'],
                minY: _dynamicMin(_dataFor(selectedRange, progressData.weightData), 0.6),
                maxY: _dynamicMax(_dataFor(selectedRange, progressData.weightData), 0.6),
                suffix: 'kg',
                onTouched: _onPointTouched,
              ),
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Sueño',
              icon: Icons.bedtime_outlined,
              insight: _sleepInsight(_dataFor(selectedRange, progressData.sleepData)),
              child: _MetricChart(
                metricKey: 'sleep',
                color: Colors.indigo.shade400,
                points: _toSpots(_dataFor(selectedRange, progressData.sleepData)),
                labels: _labelsFor(_dataFor(selectedRange, progressData.sleepData)),
                selectedIndex: selectedMetricPoints['sleep'],
                minY: 0,
                maxY: 10,
                suffix: 'h',
                onTouched: _onPointTouched,
              ),
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Mood',
              icon: Icons.sentiment_satisfied_alt_rounded,
              insight: _moodInsight(_dataFor(selectedRange, progressData.moodData)),
              child: _MetricChart(
                metricKey: 'mood',
                color: Colors.purple.shade400,
                points: _toSpots(_dataFor(selectedRange, progressData.moodData)),
                labels: _labelsFor(_dataFor(selectedRange, progressData.moodData)),
                selectedIndex: selectedMetricPoints['mood'],
                minY: 1,
                maxY: 5,
                suffix: '/5',
                onTouched: _onPointTouched,
              ),
            ),
            const SizedBox(height: 16),
            _buildAchievementsSection(),
            const SizedBox(height: 16),
            _buildSmartInsight(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSummary(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.95, end: 1),
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.92),
              colorScheme.primaryContainer.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Gran Semana, ${progressData.userName}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              progressData.weeklyInsight,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CompactKpi(
                    label: 'CF Index',
                    value: '${progressData.currentCFIndex}',
                    icon: Icons.speed_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactKpi(
                    label: 'Racha Global',
                    value: '${progressData.globalStreak} días',
                    icon: Icons.local_fire_department_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu Evolución',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SegmentedButton<TimeRange>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: TimeRange.week, label: Text('Semana')),
            ButtonSegment(value: TimeRange.month, label: Text('Mes')),
          ],
          selected: {selectedRange},
          onSelectionChanged: (selection) {
            setState(() {
              selectedRange = selection.first;
              selectedMetricPoints.updateAll((key, value) => null);
            });
          },
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tus Hitos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _SubCard(
          title: 'Logros Desbloqueados',
          child: GridView.builder(
            itemCount: progressData.unlockedAchievements.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              final achievement = progressData.unlockedAchievements[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${achievement['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${achievement['date']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _SubCard(
          title: 'Próximos Logros',
          child: SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: progressData.upcomingAchievements.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final achievement = progressData.upcomingAchievements[index];
                final progress = ((achievement['progress'] as num?) ?? 0).toDouble().clamp(0, 100);
                return Container(
                  width: 210,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events_outlined, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${achievement['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOut,
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${progress.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartInsight(ColorScheme colorScheme) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 450),
      opacity: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              colorScheme.tertiaryContainer.withValues(alpha: 0.6),
              colorScheme.secondaryContainer.withValues(alpha: 0.4),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.secondary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_rounded, color: colorScheme.tertiary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Tracking',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(progressData.smartInsight, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPointTouched(String metricKey, int index) {
    setState(() {
      selectedMetricPoints[metricKey] = index;
    });
  }

  List<Map<String, dynamic>> _dataFor(TimeRange range, List<Map<String, dynamic>> source) {
    if (range == TimeRange.week) return source;

    final expanded = <Map<String, dynamic>>[];
    for (var i = 0; i < 4; i++) {
      for (final point in source) {
        final date = DateTime.parse(point['date'] as String).add(Duration(days: i * 7));
        final baseValue = (point['value'] as num).toDouble();
        final shifted = (baseValue + sin(i * 0.85 + baseValue / 30) * 2.2)
            .clamp(_lowerBoundFor(source), _upperBoundFor(source));
        expanded.add({'date': _toDateString(date), 'value': shifted});
      }
    }
    return expanded;
  }

  String _toDateString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<FlSpot> _toSpots(List<Map<String, dynamic>> data) {
    return [
      for (var i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), (data[i]['value'] as num).toDouble()),
    ];
  }

  List<String> _labelsFor(List<Map<String, dynamic>> data) {
    return data
        .map((e) {
          final date = DateTime.parse(e['date'] as String);
          return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
        })
        .toList();
  }

  String _metricInsight(List<Map<String, dynamic>> data, String label) {
    if (data.length < 2) return 'Sigue registrando para ver tu tendencia de $label.';

    final first = (data.first['value'] as num).toDouble();
    final last = (data.last['value'] as num).toDouble();
    final delta = last - first;
    if (delta > 0) {
      return 'Mejora de ${delta.toStringAsFixed(1)} puntos en $label.';
    }
    if (delta < 0) {
      return 'Bajó ${delta.abs().toStringAsFixed(1)} puntos. Ajusta esta área.';
    }
    return '$label estable durante este periodo.';
  }

  String _weightInsight(List<Map<String, dynamic>> data) {
    if (data.length < 2) return 'Registra más días para evaluar tu evolución de peso.';
    final first = (data.first['value'] as num).toDouble();
    final last = (data.last['value'] as num).toDouble();
    final diff = last - first;
    if (diff < 0) {
      return 'Descenso de ${diff.abs().toStringAsFixed(1)} kg en el periodo.';
    }
    if (diff > 0) {
      return 'Incremento de ${diff.toStringAsFixed(1)} kg en el periodo.';
    }
    return 'Peso estable durante el periodo.';
  }

  String _sleepInsight(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 'Sin datos de sueño disponibles.';
    final avg = data.fold<double>(0, (sum, e) => sum + (e['value'] as num).toDouble()) / data.length;
    if (avg >= 7.5) return 'Buen descanso promedio (${avg.toStringAsFixed(1)}h).';
    if (avg >= 7) return 'Descanso aceptable, intenta llegar a 7.5h.';
    return 'Sueño bajo (${avg.toStringAsFixed(1)}h), prioriza recuperación.';
  }

  String _moodInsight(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 'Sin datos de estado de ánimo.';
    final avg = data.fold<double>(0, (sum, e) => sum + (e['value'] as num).toDouble()) / data.length;
    if (avg >= 4.2) return 'Estado de ánimo alto y estable.';
    if (avg >= 3.6) return 'Ánimo equilibrado en general.';
    return 'Ánimo irregular, apóyate en hábitos de recuperación.';
  }

  double _lowerBoundFor(List<Map<String, dynamic>> source) {
    final values = source.map((e) => (e['value'] as num).toDouble()).toList();
    return values.reduce(min) - 0.5;
  }

  double _upperBoundFor(List<Map<String, dynamic>> source) {
    final values = source.map((e) => (e['value'] as num).toDouble()).toList();
    return values.reduce(max) + 0.5;
  }

  double _dynamicMin(List<Map<String, dynamic>> data, double margin) {
    if (data.isEmpty) return 0;
    final minValue = data.map((e) => (e['value'] as num).toDouble()).reduce(min);
    return minValue - margin;
  }

  double _dynamicMax(List<Map<String, dynamic>> data, double margin) {
    if (data.isEmpty) return 10;
    final maxValue = data.map((e) => (e['value'] as num).toDouble()).reduce(max);
    return maxValue + margin;
  }
}

class _CompactKpi extends StatelessWidget {
  const _CompactKpi({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
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
    required this.icon,
    required this.child,
    required this.insight,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String insight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 10),
          Text(
            insight,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({
    required this.metricKey,
    required this.color,
    required this.points,
    required this.labels,
    required this.selectedIndex,
    required this.minY,
    required this.maxY,
    required this.suffix,
    required this.onTouched,
  });

  final String metricKey;
  final Color color;
  final List<FlSpot> points;
  final List<String> labels;
  final int? selectedIndex;
  final double minY;
  final double maxY;
  final String suffix;
  final void Function(String metricKey, int index) onTouched;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 168,
        child: Center(child: Text('Sin datos disponibles', style: Theme.of(context).textTheme.bodyMedium)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: max(1, (points.length / 4).floor()).toDouble(),
                    getTitlesWidget: (value, _) {
                      final i = value.round();
                      if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[i],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final label = labels[spot.x.round()];
                      return LineTooltipItem(
                        '$label\n${spot.y.toStringAsFixed(1)} $suffix',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) return;
                  final touched = response?.lineBarSpots;
                  if (touched == null || touched.isEmpty) return;
                  onTouched(metricKey, touched.first.x.round());
                },
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: points,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) =>
                        selectedIndex == null || selectedIndex == spot.x.round(),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          selectedIndex == null
              ? 'Toca un punto para ver detalle.'
              : 'Detalle: ${labels[selectedIndex!]} · ${points[selectedIndex!].y.toStringAsFixed(1)} $suffix',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
