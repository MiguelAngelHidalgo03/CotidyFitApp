import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/daily_data_model.dart';
import '../../services/daily_data_service.dart';

class HomeExtrasSection extends StatelessWidget {
  const HomeExtrasSection({
    super.key,
    required this.data,
    required this.completedToday,
    required this.onSetEnergy,
    required this.onSetMood,
    required this.onSetStress,
    required this.onSetSleep,
    required this.quickSteps,
    required this.quickWaterLiters,
    required this.quickMealsLoggedCount,
    required this.quickActiveMinutes,
    required this.onEditSteps,
    required this.onAddWater250ml,
    required this.onEditWaterLiters,
    required this.onEditActiveMinutes,
    required this.onGoToAchievements,
  });

  final DailyDataModel data;
  final bool completedToday;

  final ValueChanged<int> onSetEnergy;
  final ValueChanged<int> onSetMood;
  final ValueChanged<int> onSetStress;
  final ValueChanged<int> onSetSleep;

  final int quickSteps;
  final double quickWaterLiters;
  final int quickMealsLoggedCount;
  final int quickActiveMinutes;

  final ValueChanged<int> onEditSteps;
  final Future<void> Function() onAddWater250ml;
  final ValueChanged<double> onEditWaterLiters;
  final ValueChanged<int> onEditActiveMinutes;

  final VoidCallback onGoToAchievements;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeelingsSection(
          data: data,
          completedToday: completedToday,
          onSetEnergy: onSetEnergy,
          onSetMood: onSetMood,
          onSetStress: onSetStress,
          onSetSleep: onSetSleep,
        ),
        const SizedBox(height: 18),
        _QuickActivityGrid(
          completedToday: completedToday,
          steps: quickSteps,
          waterLiters: quickWaterLiters,
          mealsLoggedCount: quickMealsLoggedCount,
          activeMinutes: quickActiveMinutes,
          onEditSteps: onEditSteps,
          onAddWater250ml: onAddWater250ml,
          onEditWaterLiters: onEditWaterLiters,
          onEditActiveMinutes: onEditActiveMinutes,
        ),
        const SizedBox(height: 18),
        _AchievementsCard(onGoToAchievements: onGoToAchievements),
        const SizedBox(height: 18),
        const _PremiumPromoCard(),
        const SizedBox(height: 18),
        const _MotivationalFooter(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _FeelingsSection extends StatefulWidget {
  const _FeelingsSection({
    required this.data,
    required this.completedToday,
    required this.onSetEnergy,
    required this.onSetMood,
    required this.onSetStress,
    required this.onSetSleep,
  });

  final DailyDataModel data;
  final bool completedToday;
  final ValueChanged<int> onSetEnergy;
  final ValueChanged<int> onSetMood;
  final ValueChanged<int> onSetStress;
  final ValueChanged<int> onSetSleep;

  @override
  State<_FeelingsSection> createState() => _FeelingsSectionState();
}

class _FeelingsSectionState extends State<_FeelingsSection> {
  String? _autoOpenedForDateKey;

  bool get _hasAllFeelings {
    final d = widget.data;
    return d.energy != null &&
        d.mood != null &&
        d.stress != null &&
        d.sleep != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeAutoOpen();
  }

  @override
  void didUpdateWidget(covariant _FeelingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.dateKey != widget.data.dateKey) {
      _autoOpenedForDateKey = null;
    }
    _maybeAutoOpen();
  }

  void _maybeAutoOpen() {
    if (!mounted) return;
    if (widget.completedToday) return;
    if (_hasAllFeelings) return;

    final dateKey = widget.data.dateKey;
    if (_autoOpenedForDateKey == dateKey) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    _autoOpenedForDateKey = dateKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.completedToday) return;
      if (_hasAllFeelings) return;
      _openFeelingsModal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final completedToday = widget.completedToday;

    final showCards = _hasAllFeelings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('¿Cómo te sientes hoy?'),
        const SizedBox(height: 10),
        if (!showCards)
          _RegisterFeelingsButton(
            disabled: completedToday,
            onTap: completedToday ? null : _openFeelingsModal,
          )
        else
          SizedBox(
            height: 138,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _MiniFeelingCard(
                  title: 'Energía',
                  icon: Icons.bolt,
                  rating: data.energy,
                  // Display-only after accepting.
                  disabled: true,
                  onSet: (_) {},
                ),
                const SizedBox(width: 12),
                _MiniFeelingCard(
                  title: 'Ánimo',
                  icon: Icons.sentiment_satisfied_alt,
                  rating: data.mood,
                  disabled: true,
                  onSet: (_) {},
                ),
                const SizedBox(width: 12),
                _MiniFeelingCard(
                  title: 'Estrés',
                  icon: Icons.self_improvement,
                  rating: data.stress,
                  disabled: true,
                  onSet: (_) {},
                ),
                const SizedBox(width: 12),
                _MiniFeelingCard(
                  title: 'Sueño',
                  icon: Icons.nightlight_round,
                  rating: data.sleep,
                  disabled: true,
                  onSet: (_) {},
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openFeelingsModal() async {
    final initialEnergy = widget.data.energy ?? 3;
    final initialMood = widget.data.mood ?? 3;
    final initialStress = widget.data.stress ?? 3;
    final initialSleep = widget.data.sleep ?? 3;

    final result = await showModalBottomSheet<_FeelingsValues>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: CFColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var energy = initialEnergy;
        var mood = initialMood;
        var stress = initialStress;
        var sleep = initialSleep;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottom = MediaQuery.viewInsetsOf(ctx).bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar cómo te sientes hoy',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeelingsPickerRow(
                      title: 'Energía',
                      icon: Icons.bolt,
                      value: energy,
                      onSet: (v) => setModalState(() => energy = v),
                    ),
                    const SizedBox(height: 10),
                    _FeelingsPickerRow(
                      title: 'Ánimo',
                      icon: Icons.sentiment_satisfied_alt,
                      value: mood,
                      onSet: (v) => setModalState(() => mood = v),
                    ),
                    const SizedBox(height: 10),
                    _FeelingsPickerRow(
                      title: 'Estrés',
                      icon: Icons.self_improvement,
                      value: stress,
                      onSet: (v) => setModalState(() => stress = v),
                    ),
                    const SizedBox(height: 10),
                    _FeelingsPickerRow(
                      title: 'Sueño',
                      icon: Icons.nightlight_round,
                      value: sleep,
                      onSet: (v) => setModalState(() => sleep = v),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: CFColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: Theme.of(ctx).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop(
                            _FeelingsValues(
                              energy: energy,
                              mood: mood,
                              stress: stress,
                              sleep: sleep,
                            ),
                          );
                        },
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    // Persist into DailyDataModel via the provided callbacks.
    widget.onSetEnergy(result.energy);
    widget.onSetMood(result.mood);
    widget.onSetStress(result.stress);
    widget.onSetSleep(result.sleep);
  }
}

class _RegisterFeelingsButton extends StatelessWidget {
  const _RegisterFeelingsButton({required this.disabled, required this.onTap});

  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CFColors.primary,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(color: CFColors.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Registrar cómo te sientes hoy',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white.withValues(alpha: disabled ? 0.35 : 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeelingsPickerRow extends StatelessWidget {
  const _FeelingsPickerRow({
    required this.title,
    required this.icon,
    required this.value,
    required this.onSet,
  });

  final String title;
  final IconData icon;
  final int value;
  final ValueChanged<int> onSet;

  static String _levelText(int v) {
    if (v <= 2) return 'Bajo';
    if (v == 3) return 'Medio';
    return 'Alto';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.primary.withValues(alpha: 0.14)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CFColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _levelText(value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: CFColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StarsRow(value: value, disabled: false, onSet: onSet),
        ],
      ),
    );
  }
}

class _FeelingsValues {
  const _FeelingsValues({
    required this.energy,
    required this.mood,
    required this.stress,
    required this.sleep,
  });

  final int energy;
  final int mood;
  final int stress;
  final int sleep;
}

class _MiniFeelingCard extends StatelessWidget {
  const _MiniFeelingCard({
    required this.title,
    required this.icon,
    required this.rating,
    required this.disabled,
    required this.onSet,
  });

  final String title;
  final IconData icon;
  final int? rating;
  final bool disabled;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CFColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StarsRow(value: rating, disabled: disabled, onSet: onSet),
          const Spacer(),
          Text(
            rating == null ? 'Sin registrar' : 'Registrado',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: rating == null ? CFColors.textSecondary : CFColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({
    required this.value,
    required this.disabled,
    required this.onSet,
  });

  final int? value;
  final bool disabled;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          _StarTap(
            filled: current != null && i <= current,
            disabled: disabled,
            onTap: () => onSet(i),
          ),
      ],
    );
  }
}

class _StarTap extends StatelessWidget {
  const _StarTap({
    required this.filled,
    required this.disabled,
    required this.onTap,
  });

  final bool filled;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          child: Center(
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              color: CFColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActivityGrid extends StatelessWidget {
  const _QuickActivityGrid({
    required this.completedToday,
    required this.steps,
    required this.waterLiters,
    required this.mealsLoggedCount,
    required this.activeMinutes,
    required this.onEditSteps,
    required this.onAddWater250ml,
    required this.onEditWaterLiters,
    required this.onEditActiveMinutes,
  });

  final bool completedToday;
  final int steps;
  final double waterLiters;
  final int mealsLoggedCount;
  final int activeMinutes;
  final ValueChanged<int> onEditSteps;
  final Future<void> Function() onAddWater250ml;
  final ValueChanged<double> onEditWaterLiters;
  final ValueChanged<int> onEditActiveMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actividad rápida'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Slightly taller tiles to avoid vertical overflows on small widths.
          childAspectRatio: 1.05,
          children: [
            _MiniMetricCard(
              title: 'Pasos',
              icon: Icons.directions_walk,
              value: '$steps',
              disabled: completedToday,
              onTap: () => _editNumber(
                context: context,
                title: 'Pasos',
                hint: 'Ej: 8200',
                initial: steps,
                onSave: onEditSteps,
              ),
            ),
            _MiniMetricCard(
              title: 'Agua',
              icon: Icons.water_drop_outlined,
              value: '',
              customChild: _WaterLitersCard(
                liters: waterLiters,
                targetLiters: DailyDataService.waterLitersTarget,
                disabled: completedToday,
                onAdd250ml: onAddWater250ml,
                onEdit: () => _editLiters(
                  context: context,
                  title: 'Editar agua (litros)',
                  hint: 'Ej: 2.5',
                  initial: waterLiters,
                  onSave: onEditWaterLiters,
                ),
              ),
              disabled: true,
              onTap: () {},
            ),
            _MiniMetricCard(
              title: 'Comidas',
              icon: Icons.restaurant_outlined,
              value: '$mealsLoggedCount',
              disabled: true,
              onTap: () {},
            ),
            _MiniMetricCard(
              title: 'Min activos',
              icon: Icons.timer_outlined,
              value: '$activeMinutes',
              disabled: completedToday,
              onTap: () => _editNumber(
                context: context,
                title: 'Min activos',
                hint: 'Ej: 30',
                initial: activeMinutes,
                onSave: onEditActiveMinutes,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editNumber({
    required BuildContext context,
    required String title,
    required String hint,
    required int initial,
    required ValueChanged<int> onSave,
  }) async {
    final controller = TextEditingController(
      text: initial <= 0 ? '' : '$initial',
    );

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final v = int.tryParse(controller.text.trim());
                        Navigator.of(ctx).pop(v ?? 0);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    onSave(result);
  }

  Future<void> _editLiters({
    required BuildContext context,
    required String title,
    required String hint,
    required double initial,
    required ValueChanged<double> onSave,
  }) async {
    final controller = TextEditingController(
      text: initial <= 0 ? '' : initial.toStringAsFixed(2),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final raw = controller.text.trim().replaceAll(',', '.');
                        final v = double.tryParse(raw);
                        Navigator.of(ctx).pop(v ?? 0.0);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    onSave(result);
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.title,
    required this.icon,
    required this.value,
    this.customChild,
    required this.disabled,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String value;
  final Widget? customChild;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CFColors.surface,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Container(
          decoration: BoxDecoration(
            color: CFColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(color: CFColors.softGray),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: CFColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              if (customChild != null) ...[
                const SizedBox(height: 10),
                Expanded(child: customChild!),
              ] else ...[
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: CFColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disabled ? 'Bloqueado' : 'Toca para editar',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CFColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WaterLitersCard extends StatelessWidget {
  const _WaterLitersCard({
    required this.liters,
    required this.targetLiters,
    required this.disabled,
    required this.onAdd250ml,
    required this.onEdit,
  });

  final double liters;
  final double targetLiters;
  final bool disabled;
  final Future<void> Function() onAdd250ml;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = liters < 0 ? 0.0 : liters;
    final progress = (targetLiters <= 0)
        ? 0.0
        : (l / targetLiters).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Text(
            '${_fmtLitersValue(l)} / ${targetLiters.toStringAsFixed(1)} L',
            key: ValueKey(l.toStringAsFixed(2)),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: CFColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: CFColors.softGray,
                valueColor: const AlwaysStoppedAnimation(CFColors.primary),
              );
            },
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: disabled
                ? null
                : () async {
                    await onAdd250ml();
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: const Text('+250 ml'),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: disabled ? null : onEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            child: const Text('Editar cantidad'),
          ),
        ),
      ],
    );
  }

  String _fmtLitersValue(double liters) {
    final s = liters.toStringAsFixed((liters * 100).round() % 10 == 0 ? 1 : 2);
    return s;
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.onGoToAchievements});

  final VoidCallback onGoToAchievements;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Logros',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: onGoToAchievements,
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: CFColors.softGray),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: CFColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu colección',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ver todos los logros',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumPromoCard extends StatelessWidget {
  const _PremiumPromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: CFColors.primary.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: const Icon(Icons.workspace_premium, color: CFColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan personalizado y recomendaciones.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: null, child: const Text('Próximamente')),
        ],
      ),
    );
  }
}

class _MotivationalFooter extends StatelessWidget {
  const _MotivationalFooter();

  @override
  Widget build(BuildContext context) {
    final quotes = <String>[
      'Pequeños hábitos, grandes cambios.',
      'Hoy cuenta. Hazlo simple.',
      'Constancia > perfección.',
      'Un día a la vez.',
      'Tu salud es tu mejor inversión.',
    ];

    final now = DateTime.now();
    final idx = (now.year + now.month + now.day) % quotes.length;

    return Center(
      child: Text(
        '“${quotes[idx]}”',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: CFColors.textSecondary,
        ),
      ),
    );
  }
}
