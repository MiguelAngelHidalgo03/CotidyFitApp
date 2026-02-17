import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/local_storage_service.dart';
import '../services/progress_service.dart';
import '../services/weight_service.dart';
import '../services/workout_history_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/progress_day_sheet.dart';
import '../widgets/progress/progress_future_tracking.dart';
import '../widgets/progress/progress_insights_section.dart';
import '../widgets/progress/progress_metrics_grid.dart';
import '../widgets/progress/progress_month_calendar.dart';
import '../widgets/progress/progress_premium_card.dart';
import '../widgets/progress/progress_section_card.dart';
import 'profile_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final LocalStorageService _storage;
  late final ProgressService _service;
  late final WeightService _weightService;
  late final WorkoutHistoryService _workoutHistory;

  ProgressData? _data;
  WeightSummary? _weight;
  Map<String, int> _cfHistory = const {};
  Map<String, String> _completedWorkoutsByDate = const {};
  bool _loading = true;

  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _storage = LocalStorageService();
    _service = ProgressService(storage: _storage);
    _weightService = WeightService();
    _workoutHistory = WorkoutHistoryService();

    final today = DateUtilsCF.dateOnly(DateTime.now());
    _focusedDay = DateTime(today.year, today.month, 1);
    _selectedDay = today;

    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _service.loadProgress(days: 7);
    final w = await _weightService.getSummary(maxPoints: 30);
    final history = await _storage.getCfHistory();
    final workouts = await _workoutHistory.getCompletedWorkoutsByDate();
    if (!mounted) return;
    setState(() {
      _data = d;
      _weight = w;
      _cfHistory = history;
      _completedWorkoutsByDate = workouts;
      _loading = false;
    });
  }

  Future<void> _addWeightFlow() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir peso'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            decoration: const InputDecoration(
              hintText: 'Ej: 72.5',
              suffixText: 'kg',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) return;
                Navigator.of(context).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await _weightService.upsertToday(result);
    final w = await _weightService.getSummary(maxPoints: 30);
    if (!mounted) return;
    setState(() => _weight = w);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? Center(
                    child: Text(
                      'No hay datos aún.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: _buildBody(context, _data!),
                    ),
                  ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, ProgressData data) {
    final avgMessage = _service.motivationalMessageForAverage(data.average7Days);
    final calendarData = _buildCalendarData();
    final monthAverage = _monthAverageCf(_focusedDay, _cfHistory);
    final maxStreak = _maxStreakFromHistory(_cfHistory);
    final insights = _buildInsights(data: data);

    return [
      Row(
        children: [
          Expanded(
            child: Text('Progreso', style: Theme.of(context).textTheme.titleLarge),
          ),
          IconButton(
            tooltip: 'Perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _ProgressHeroCard(
        currentCf: data.currentCf,
        average7Days: data.average7Days,
        message: avgMessage,
      ),
      const SizedBox(height: 18),
      ProgressMonthCalendar(
        focusedDay: _focusedDay,
        selectedDay: _selectedDay,
        dataByDateKey: calendarData,
        onPrevMonth: _prevMonth,
        onNextMonth: _nextMonth,
        onPickMonthYear: _pickMonthYear,
        onDaySelected: (d) {
          setState(() {
            _selectedDay = d;
            _focusedDay = DateTime(d.year, d.month, 1);
          });
          _openDaySheet(d);
        },
      ),
      const SizedBox(height: 18),
      ProgressMetricsGrid(
        last7Days: data.last7Days,
        monthAverageCf: monthAverage,
        weight: _weight,
        maxStreak: maxStreak,
        totalWorkouts: _completedWorkoutsByDate.length,
        nutritionPercentLabel: '— (próximamente)',
        onAddWeight: _addWeightFlow,
      ),
      const SizedBox(height: 18),
      const ProgressFutureTracking(),
      const SizedBox(height: 18),
      ProgressInsightsSection(insights: insights),
      const SizedBox(height: 18),
      const ProgressPremiumCard(),
      const SizedBox(height: 10),
    ];
  }

  Map<String, ProgressCalendarDayData> _buildCalendarData() {
    final keys = <String>{..._cfHistory.keys, ..._completedWorkoutsByDate.keys};
    final out = <String, ProgressCalendarDayData>{};
    for (final k in keys) {
      out[k] = ProgressCalendarDayData(
        cf: _cfHistory[k] ?? 0,
        trained: _completedWorkoutsByDate.containsKey(k),
      );
    }
    return out;
  }

  void _prevMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    });
  }

  Future<void> _pickMonthYear() async {
    final picked = await _showMonthYearPickerSheet(initialMonth: _focusedDay);
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _focusedDay = DateTime(picked.year, picked.month, 1);
    });
  }

  Future<DateTime?> _showMonthYearPickerSheet({required DateTime initialMonth}) {
    final initialYear = initialMonth.year;
    final initialMonthNumber = initialMonth.month;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var selectedYear = initialYear;
        var selectedMonth = initialMonthNumber;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return ProgressSectionCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mes y año',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Cerrar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 220,
                        child: YearPicker(
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                          selectedDate: DateTime(selectedYear, 1, 1),
                          onChanged: (d) {
                            setSheetState(() => selectedYear = d.year);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(12, (i) {
                          final m = i + 1;
                          final isSelected = selectedMonth == m;
                          return ChoiceChip(
                            label: Text(_monthShortLabel(m)),
                            selected: isSelected,
                            onSelected: (_) {
                              setSheetState(() => selectedMonth = m);
                            },
                            selectedColor: CFColors.primary.withValues(alpha: 0.12),
                            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? CFColors.primary : CFColors.textSecondary,
                                ),
                            side: BorderSide(
                              color: isSelected ? CFColors.primary : CFColors.softGray,
                            ),
                            backgroundColor: CFColors.background,
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop(DateTime(selectedYear, selectedMonth, 1));
                          },
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _monthShortLabel(int month) {
    const months = <String>[
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  void _openDaySheet(DateTime day) {
    final key = DateUtilsCF.toKey(day);
    final cf = _cfHistory[key] ?? 0;
    final workoutName = _completedWorkoutsByDate[key];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ProgressDaySheet(
          details: ProgressDayDetails(day: day, cf: cf, workoutName: workoutName),
        );
      },
    );
  }

  int _monthAverageCf(DateTime focusedMonth, Map<String, int> history) {
    final values = <int>[];
    for (final e in history.entries) {
      final d = DateUtilsCF.fromKey(e.key);
      if (d == null) continue;
      if (d.year != focusedMonth.year || d.month != focusedMonth.month) continue;
      if (e.value <= 0) continue;
      values.add(e.value);
    }
    if (values.isEmpty) return 0;
    final sum = values.fold<int>(0, (a, b) => a + b);
    return (sum / values.length).round().clamp(0, 100);
  }

  int _maxStreakFromHistory(Map<String, int> history) {
    final days = <DateTime>[];
    for (final e in history.entries) {
      if (e.value <= 0) continue;
      final d = DateUtilsCF.fromKey(e.key);
      if (d != null) days.add(DateUtilsCF.dateOnly(d));
    }
    if (days.isEmpty) return 0;
    days.sort((a, b) => a.compareTo(b));

    var best = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
      } else if (diff == 0) {
        continue;
      } else {
        best = best > current ? best : current;
        current = 1;
      }
    }
    best = best > current ? best : current;
    return best;
  }

  List<ProgressInsight> _buildInsights({required ProgressData data}) {
    final insights = <ProgressInsight>[];

    if (data.average7Days >= 80) {
      insights.add(const ProgressInsight(
        icon: Icons.star_outline,
        title: 'Constancia alta',
        description: 'Tu promedio semanal está en un nivel excelente. Mantén el ritmo.',
      ));
    } else if (data.average7Days >= 50) {
      insights.add(const ProgressInsight(
        icon: Icons.trending_up,
        title: 'Buen progreso',
        description: 'Vas bien. Con 1-2 días fuertes más, subes de nivel rápido.',
      ));
    } else {
      insights.add(const ProgressInsight(
        icon: Icons.rocket_launch_outlined,
        title: 'Oportunidad esta semana',
        description: 'Un pequeño empujón diario puede cambiar tu promedio en pocos días.',
      ));
    }

    final p = data.last7Days;
    if (p.length >= 6) {
      final a1 = ((p[0].value + p[1].value + p[2].value) / 3).round();
      final a2 = ((p[4].value + p[5].value + p[6].value) / 3).round();
      if (a2 >= a1 + 8) {
        insights.add(const ProgressInsight(
          icon: Icons.trending_up,
          title: 'Tendencia al alza',
          description: 'Tu CF reciente está mejorando. Sigue repitiendo lo que te funciona.',
        ));
      } else if (a1 >= a2 + 8) {
        insights.add(const ProgressInsight(
          icon: Icons.trending_down,
          title: 'Bajada reciente',
          description: 'Esta semana aflojó un poco. Vuelve a lo básico: agua, pasos y entreno.',
        ));
      } else {
        insights.add(const ProgressInsight(
          icon: Icons.insights_outlined,
          title: 'Semana estable',
          description: 'Tu CF está consistente. Un hábito extra puede empujarte hacia arriba.',
        ));
      }
    }

    final today = DateUtilsCF.dateOnly(DateTime.now());
    var workouts7 = 0;
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final k = DateUtilsCF.toKey(d);
      if (_completedWorkoutsByDate.containsKey(k)) workouts7 += 1;
    }
    insights.add(ProgressInsight(
      icon: Icons.fitness_center_outlined,
      title: 'Entrenos últimos 7 días',
      description: workouts7 == 0
          ? 'Aún no hay entrenos registrados esta semana.'
          : 'Llevas $workouts7 entreno${workouts7 == 1 ? '' : 's'} esta semana.',
    ));

    return insights;
  }
}

class _ProgressHeroCard extends StatelessWidget {
  const _ProgressHeroCard({
    required this.currentCf,
    required this.average7Days,
    required this.message,
  });

  final int currentCf;
  final int average7Days;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  title: 'CF actual',
                  value: '$currentCf',
                  subtitle: 'de 100',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetric(
                  title: 'Prom. 7 días',
                  value: '$average7Days',
                  subtitle: 'de 100',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: CFColors.primary,
                ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
