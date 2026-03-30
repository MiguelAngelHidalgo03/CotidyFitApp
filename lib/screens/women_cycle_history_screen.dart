import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/women_cycle_service.dart';
import '../widgets/progress/progress_section_card.dart';

class WomenCycleHistoryScreen extends StatefulWidget {
  const WomenCycleHistoryScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<WomenCycleHistoryScreen> createState() => _WomenCycleHistoryScreenState();
}

class _WomenCycleHistoryScreenState extends State<WomenCycleHistoryScreen> {
  final WomenCycleService _service = WomenCycleService();

  WomenCycleData? _current;
  List<WomenCycleData> _history = const [];
  bool _loading = true;

  bool get _isFemale => widget.profile.sex == UserSex.mujer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isFemale) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    final current = await _service.getCurrentCycle();
    final history = await _service.getCycleHistory();
    if (!mounted) return;
    setState(() {
      _current = current;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _startPeriod() async {
    await _service.startPeriod();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Regla iniciada y guardada.')),
    );
    await _load();
  }

  Future<void> _endPeriod() async {
    final updated = await _service.endPeriod();
    if (!mounted || updated == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fin de regla guardado.')),
    );
    await _load();
  }

  String _fmt(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _rangeLabel(WomenCycleData cycle) {
    if (cycle.end == null) {
      return 'Desde ${_fmt(cycle.start)} · En curso';
    }
    return '${_fmt(cycle.start)} - ${_fmt(cycle.end!)}';
  }

  String _durationLabel(WomenCycleData cycle) {
    final end = cycle.end ?? DateTime.now();
    final days = end.difference(cycle.start).inDays + 1;
    if (days <= 1) return '1 día';
    return '$days días';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ciclo femenino')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isFemale
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Este apartado solo se muestra para perfiles configurados como mujer.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ProgressSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.favorite_outline),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tu seguimiento',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                if (_current != null && _current!.isOpen)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(999),
                                      ),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error
                                            .withValues(alpha: 0.45),
                                      ),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withValues(alpha: 0.14),
                                    ),
                                    child: Text(
                                      'Regla activa',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _current == null
                                  ? 'Todavía no has guardado ninguna fecha.'
                                  : _rangeLabel(_current!),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (_current != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Duración: ${_durationLabel(_current!)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Tus fechas se guardan en este móvil y, si has iniciado sesión, también en tu cuenta en la nube.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: context.cfTextSecondary),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: (_current != null && _current!.isOpen)
                                      ? FilledButton.icon(
                                          onPressed: _endPeriod,
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: const Text(
                                            'Se me acabó la regla',
                                          ),
                                        )
                                      : FilledButton.icon(
                                          onPressed: _startPeriod,
                                          icon: const Icon(
                                            Icons.water_drop_outlined,
                                          ),
                                          label: const Text('Tengo la regla'),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Historial guardado',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        ProgressSectionCard(
                          child: Text(
                            'Aún no hay registros guardados de tu ciclo.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        for (final cycle in _history) ...[
                          ProgressSectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _rangeLabel(cycle),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                    if (cycle.isOpen)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(999),
                                          ),
                                          color: context.cfSoftSurface,
                                          border: Border.all(
                                            color: context.cfBorder,
                                          ),
                                        ),
                                        child: Text(
                                          'Actual',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Duración: ${_durationLabel(cycle)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
    );
  }
}