import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/daily_data_model.dart';

class HomeMoodSection extends StatelessWidget {
  const HomeMoodSection({
    super.key,
    required this.data,
    required this.onSetEnergy,
    required this.onSetMood,
    required this.onSetStress,
    required this.onSetSleep,
  });

  final DailyDataModel data;
  final ValueChanged<int> onSetEnergy;
  final ValueChanged<int> onSetMood;
  final ValueChanged<int> onSetStress;
  final ValueChanged<int> onSetSleep;

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
          Text('¿Cómo te sientes hoy?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Puedes cambiarlo cuando quieras durante el día.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CFColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          _MoodRow(
            title: 'Energía',
            options: const ['Baja', 'Media', 'Alta'],
            initialIndex: _fromLevel5(data.energy),
            onSelect: (idx) => onSetEnergy(_idxToLevel5(idx)),
          ),
          const SizedBox(height: 10),
          _MoodRow(
            title: 'Ánimo',
            options: const ['Bajo', 'Medio', 'Alto'],
            initialIndex: _fromLevel5(data.mood),
            onSelect: (idx) => onSetMood(_idxToLevel5(idx)),
          ),
          const SizedBox(height: 10),
          _MoodRow(
            title: 'Estrés',
            options: const ['Bajo', 'Medio', 'Alto'],
            initialIndex: _fromLevel5(data.stress),
            onSelect: (idx) => onSetStress(_idxToLevel5(idx)),
          ),
          const SizedBox(height: 10),
          _MoodRow(
            title: 'Sueño',
            options: const ['Malo', 'Normal', 'Bueno'],
            initialIndex: _fromLevel5(data.sleep),
            onSelect: (idx) => onSetSleep(_idxToLevel5(idx)),
          ),
        ],
      ),
    );
  }

  static int _idxToLevel5(int index) {
    switch (index) {
      case 0:
        return 2;
      case 2:
        return 5;
      default:
        return 3;
    }
  }

  static int? _fromLevel5(int? value) {
    if (value == null) return null;
    if (value <= 2) return 0;
    if (value >= 4) return 2;
    return 1;
  }
}

class _MoodRow extends StatefulWidget {
  const _MoodRow({
    required this.title,
    required this.options,
    required this.initialIndex,
    required this.onSelect,
  });

  final String title;
  final List<String> options;
  final int? initialIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_MoodRow> createState() => _MoodRowState();
}

class _MoodRowState extends State<_MoodRow> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant _MoodRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selected = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < widget.options.length; i++)
                    SizedBox(
                      width: width,
                      child: ChoiceChip(
                        label: Center(child: Text(widget.options[i])),
                        selected: _selected == i,
                        showCheckmark: false,
                        selectedColor: CFColors.primary.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: _selected == i
                              ? CFColors.primary.withValues(alpha: 0.55)
                              : CFColors.softGray,
                        ),
                        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _selected == i
                                  ? CFColors.primary
                                  : CFColors.textPrimary,
                            ),
                        onSelected: (_) {
                          setState(() => _selected = i);
                          widget.onSelect(i);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
