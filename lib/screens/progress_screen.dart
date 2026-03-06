import 'package:flutter/material.dart';

import '../models/progress_advanced_analytics.dart';
import '../models/user_profile.dart';
import '../screens/achievements_screen.dart';
import '../services/health_service.dart';
import '../services/local_storage_service.dart';
import '../services/profile_service.dart';
import '../services/progress_service.dart';
import '../services/progress_advanced_analytics_service.dart';
import '../services/progress_week_summary_service.dart';
import '../services/recipe_repository.dart';
import '../services/recipes_repository_factory.dart';
import '../services/weight_service.dart';
import '../services/women_cycle_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/header_profile.dart';
import '../widgets/progress/progress_advanced_dashboard.dart';
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
  late final ProfileService _profiles;
  late final ProgressWeekSummaryService _weekSummaryService;
  late final ProgressAdvancedAnalyticsService _advancedService;
  late final WomenCycleService _womenCycleService;
  late final RecipeRepository _recipes;

  ProgressData? _data;
  UserProfile? _profile;
  ProgressAdvancedAnalytics? _advancedAnalytics;
  WomenCycleData? _cycleData;
  List<WomenCycleFoodTip> _cycleTips = const [];
  bool _loading = true;
  bool _savingWeight = false;

  @override
  void initState() {
    super.initState();
    _storage = LocalStorageService();
    _service = ProgressService(storage: _storage);
    _weightService = WeightService();
    _profiles = ProfileService();
    _weekSummaryService = ProgressWeekSummaryService(storage: _storage);
    _advancedService = ProgressAdvancedAnalyticsService(
      progress: _service,
      weekSummary: _weekSummaryService,
      storage: _storage,
    );
    _womenCycleService = WomenCycleService();
    _recipes = RecipesRepositoryFactory.create();

    _load();
  }

  Future<void> _load({bool withLoader = true}) async {
    if (withLoader && mounted) setState(() => _loading = true);
    try {
      final profile = await _profiles.getOrCreateProfile();

      // Best-effort: sync steps from device health data so Progress can use them.
      await _syncStepsFromHealthBestEffort();

      final data = await _service.loadProgress(days: 7);
      final advanced = await _advancedService.load(profile: profile);
      final cycleData = await _womenCycleService.getCurrentCycle();
      final recipes = await _recipes.getAllRecipes();
      final cycleTips = _profileIsFemale(profile)
          ? _womenCycleService.buildFoodTips(
              now: DateTime.now(),
              recipes: recipes,
            )
          : const <WomenCycleFoodTip>[];

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _data = data;
        _advancedAnalytics = advanced;
        _cycleData = cycleData;
        _cycleTips = cycleTips;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncStepsFromHealthBestEffort() async {
    if (_isRunningWidgetTest) return;

    try {
      await HealthService().syncTodaySteps().timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
    } catch (_) {
      // Ignore (Health Connect/HealthKit may be unavailable or permission denied).
    }
  }

  bool get _isRunningWidgetTest {
    // We cannot import `flutter_test` from production code, so detect it by
    // checking the binding runtimeType.
    try {
      final type = WidgetsBinding.instance.runtimeType.toString();
      return type.contains('TestWidgetsFlutterBinding') ||
          type.contains('AutomatedTestWidgetsFlutterBinding') ||
          type.contains('LiveTestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  Future<void> _addWeightFlow() async {
    if (_savingWeight) return;
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir peso'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    if (mounted) setState(() => _savingWeight = true);
    try {
      await _weightService.upsertToday(result);
      final profile = _profile ?? await _profiles.getOrCreateProfile();
      final advanced = await _advancedService.load(profile: profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _advancedAnalytics = advanced;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peso guardado correctamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingWeight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final analytics = _advancedAnalytics;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : data == null || analytics == null
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
                  children: _buildBody(context, analytics),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    ProgressAdvancedAnalytics analytics,
  ) {
    return [
      HeaderProfile(
        profile: _profile,
        onOpenProfile: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        },
      ),
      const SizedBox(height: 10),
      ProgressAdvancedDashboard(
        analytics: analytics,
        onAddWeight: _addWeightFlow,
        userName: (_profile?.name.trim().isEmpty ?? true)
            ? 'Usuario'
            : _profile!.name,
        currentCf: _data?.currentCf,
        womenCycleSection: _profileIsFemale(_profile)
            ? _buildWomenCycleCard(context)
            : null,
      ),
      const SizedBox(height: 10),
      Text(
        'Logros',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      _buildAchievementsEntry(context, analytics),
      const SizedBox(height: 10),
      const ProgressPremiumCard(),
      const SizedBox(height: 8),
    ];
  }

  bool _profileIsFemale(UserProfile? p) => p?.sex == UserSex.mujer;

  Widget _buildWomenCycleCard(BuildContext context) {
    final cycle = _cycleData;
    final now = DateUtilsCF.dateOnly(DateTime.now());

    final isActive = cycle != null && cycle.end == null;

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    String statusText() {
      if (cycle == null) return 'Pulsa "Tengo la regla" cuando empiece.';
      if (cycle.end == null) {
        final days = now.difference(cycle.start).inDays + 1;
        return 'Regla activa · día ${days < 1 ? 1 : days}.';
      }

      final daysAgo = now.difference(cycle.end!).inDays;
      if (daysAgo <= 0) return 'Última regla terminó hoy.';
      if (daysAgo == 1) return 'Última regla terminó ayer.';
      return 'Última regla terminó hace $daysAgo día(s).';
    }

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.female_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ciclo y nutrición femenino',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(
                      color: Colors.pink.withValues(alpha: 0.4),
                    ),
                    color: Colors.pink.withValues(alpha: 0.10),
                  ),
                  child: const Text('Regla activa'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusText(), style: Theme.of(context).textTheme.bodyMedium),
          if (cycle != null) ...[
            const SizedBox(height: 4),
            Text(
              cycle.end == null
                  ? 'Inicio: ${fmt(cycle.start)}'
                  : 'Inicio: ${fmt(cycle.start)} · Fin: ${fmt(cycle.end!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: isActive
                    ? FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final next = await _womenCycleService.endPeriod();
                          if (!mounted || next == null) return;
                          setState(() => _cycleData = next);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Fin de regla guardado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Se me acabó la regla'),
                      )
                    : FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final next = await _womenCycleService.startPeriod();
                          if (!mounted) return;
                          setState(() => _cycleData = next);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Regla iniciada.')),
                          );
                        },
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('Tengo la regla'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final tip in _cycleTips.take(3)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.restaurant_menu_outlined, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        tip.reason,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementsEntry(
    BuildContext context,
    ProgressAdvancedAnalytics analytics,
  ) {
    final s = analytics.achievements;
    final xpToLevelStart = (s.level - 1) * 250;
    final denominator = (s.nextLevelXp - xpToLevelStart).clamp(1, 1000000);
    final levelProgress = ((s.currentXp - xpToLevelStart) / denominator).clamp(
      0.0,
      1.0,
    );

    return ProgressSectionCard(
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AchievementsScreen()));
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SmallKpi(
                      label: 'Desbloqueados',
                      value: '${s.unlocked}',
                    ),
                  ),
                  Expanded(
                    child: _SmallKpi(
                      label: 'En progreso',
                      value: '${s.inProgress}',
                    ),
                  ),
                  Expanded(
                    child: _SmallKpi(label: 'Nivel', value: '${s.level}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('XP', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: levelProgress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE6EAF2),
                color: const Color(0xFF27426B),
              ),
              const SizedBox(height: 4),
              Text(
                '${s.currentXp} / ${s.nextLevelXp} XP',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (s.rarest.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Logros raros: ${s.rarest.join(' · ')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Ver detalle',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallKpi extends StatelessWidget {
  const _SmallKpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
