import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/progress/progress_section_card.dart';

class ProfileEditSheets {
  static Future<String?> editText(
    BuildContext context, {
    required String title,
    required String label,
    String initialValue = '',
    String? helper,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) async {
    final ctrl = TextEditingController(text: initialValue);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(title: title),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: keyboardType,
                    maxLength: maxLength,
                    decoration: InputDecoration(labelText: label, helperText: helper),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
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

    ctrl.dispose();
    return result;
  }

  static Future<int?> editInt(
    BuildContext context, {
    required String title,
    required String label,
    int? initialValue,
    String? suffix,
  }) async {
    final ctrl = TextEditingController(text: initialValue?.toString() ?? '');

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(title: title),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: label, suffixText: suffix),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final v = int.tryParse(ctrl.text.trim());
                        Navigator.of(context).pop(v);
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

    ctrl.dispose();
    return result;
  }

  static Future<double?> editDouble(
    BuildContext context, {
    required String title,
    required String label,
    double? initialValue,
    int? fractionDigits,
    String? suffix,
  }) async {
    final text = initialValue == null
        ? ''
        : (fractionDigits == null ? initialValue.toString() : initialValue.toStringAsFixed(fractionDigits));
    final ctrl = TextEditingController(text: text);

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(title: title),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: label, suffixText: suffix),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                        Navigator.of(context).pop(v);
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

    ctrl.dispose();
    return result;
  }

  static Future<T?> pickEnum<T>(
    BuildContext context, {
    required String title,
    required T? initialValue,
    required List<T> values,
    required String Function(T v) label,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var selected = initialValue;
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
                      _SheetHeader(title: title),
                      const SizedBox(height: 10),
                      for (final v in values) ...[
                        Card(
                          child: ListTile(
                            title: Text(label(v)),
                            leading: Icon(
                              selected == v ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: selected == v ? CFColors.primary : CFColors.textSecondary,
                            ),
                            onTap: () => setSheetState(() => selected = v),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(selected),
                          child: const Text('Guardar'),
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

  static Future<({TimeOfDay? start, TimeOfDay? end})?> pickTimeRange(
    BuildContext context, {
    required String title,
    TimeOfDay? initialStart,
    TimeOfDay? initialEnd,
  }) {
    return showModalBottomSheet<({TimeOfDay? start, TimeOfDay? end})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        TimeOfDay? start = initialStart;
        TimeOfDay? end = initialEnd;

        Future<void> pickStart() async {
          final picked = await showTimePicker(
            context: context,
            initialTime: start ?? const TimeOfDay(hour: 7, minute: 0),
          );
          if (picked == null) return;
          start = picked;
        }

        Future<void> pickEnd() async {
          final picked = await showTimePicker(
            context: context,
            initialTime: end ?? const TimeOfDay(hour: 21, minute: 0),
          );
          if (picked == null) return;
          end = picked;
        }

        int toMins(TimeOfDay t) => t.hour * 60 + t.minute;

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
                      _SheetHeader(title: title),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await pickStart();
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text(start == null ? 'Desde' : start!.format(context)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await pickEnd();
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text(end == null ? 'Hasta' : end!.format(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => setSheetState(() {
                                start = null;
                                end = null;
                              }),
                              child: const Text('Limpiar'),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                if ((start == null) != (end == null)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Completa el rango o déjalo vacío.')),
                                  );
                                  return;
                                }
                                if (start != null && end != null && toMins(start!) > toMins(end!)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('El rango no es válido.')),
                                  );
                                  return;
                                }
                                Navigator.of(context).pop((start: start, end: end));
                              },
                              child: const Text('Guardar'),
                            ),
                          ),
                        ],
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

  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    required String title,
    TimeOfDay? initial,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(title: title),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial ?? const TimeOfDay(hour: 20, minute: 0),
                        );
                        if (picked == null || !context.mounted) return;
                        Navigator.of(context).pop(picked);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(initial == null ? 'Seleccionar hora' : initial.format(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<String?> pickSingleString(
    BuildContext context, {
    required String title,
    required List<String> options,
    String? initialValue,
    bool allowEmpty = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? selected = options.contains(initialValue) ? initialValue : null;

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
                      _SheetHeader(title: title),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final o in options)
                            ChoiceChip(
                              selected: selected == o,
                              onSelected: (_) => setSheetState(() => selected = o),
                              label: Text(o),
                              selectedColor: CFColors.primary.withValues(alpha: 0.12),
                              side: BorderSide(color: selected == o ? CFColors.primary : CFColors.softGray),
                              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: selected == o ? CFColors.primary : CFColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (allowEmpty) ...[
                            Expanded(
                              child: TextButton(
                                onPressed: () => setSheetState(() => selected = null),
                                child: const Text('Limpiar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                if (!allowEmpty && selected == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Selecciona una opción.')),
                                  );
                                  return;
                                }
                                Navigator.of(context).pop(selected);
                              },
                              child: const Text('Guardar'),
                            ),
                          ),
                        ],
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

  static Future<List<String>?> pickMultiString(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Set<String> selected,
    bool allowEmpty = true,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final current = <String>{...selected};

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
                      _SheetHeader(title: title),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final o in options)
                            ChoiceChip(
                              selected: current.contains(o),
                              onSelected: (_) => setSheetState(() {
                                if (current.contains(o)) {
                                  current.remove(o);
                                } else {
                                  current.add(o);
                                }
                              }),
                              label: Text(o),
                              selectedColor: CFColors.primary.withValues(alpha: 0.12),
                              side: BorderSide(color: current.contains(o) ? CFColors.primary : CFColors.softGray),
                              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: current.contains(o) ? CFColors.primary : CFColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (!allowEmpty && current.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selecciona al menos una opción.')),
                              );
                              return;
                            }
                            final list = current.toList()..sort();
                            Navigator.of(context).pop(list);
                          },
                          child: const Text('Guardar'),
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

  static Future<List<int>?> pickDays(
    BuildContext context, {
    required String title,
    required Set<int> selected,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final current = <int>{...selected};

        String dayLabel(int d) {
          return switch (d) {
            1 => 'L',
            2 => 'M',
            3 => 'X',
            4 => 'J',
            5 => 'V',
            6 => 'S',
            _ => 'D',
          };
        }

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
                      _SheetHeader(title: title),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final d in const <int>[1, 2, 3, 4, 5, 6, 7])
                            ChoiceChip(
                              selected: current.contains(d),
                              onSelected: (_) => setSheetState(() {
                                if (current.contains(d)) {
                                  current.remove(d);
                                } else {
                                  current.add(d);
                                }
                              }),
                              label: Text(dayLabel(d)),
                              selectedColor: CFColors.primary.withValues(alpha: 0.12),
                              side: BorderSide(color: current.contains(d) ? CFColors.primary : CFColors.softGray),
                              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: current.contains(d) ? CFColors.primary : CFColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (current.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selecciona al menos un día.')),
                              );
                              return;
                            }
                            final list = current.toList()..sort();
                            Navigator.of(context).pop(list);
                          },
                          child: const Text('Guardar'),
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
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
