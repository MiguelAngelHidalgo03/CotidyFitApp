import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/progress/progress_section_card.dart';

class IngredientCheckItem {
  const IngredientCheckItem({required this.key, required this.label});

  /// Normalized key (e.g. lowercased ingredient name).
  final String key;

  /// Human-friendly label to display.
  final String label;
}

class IngredientCheckBottomSheet extends StatefulWidget {
  const IngredientCheckBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.initialHaveKeys,
    required this.onChanged,
  });

  final String title;
  final List<IngredientCheckItem> items;
  final Set<String> initialHaveKeys;

  /// Called with normalized keys.
  final ValueChanged<Set<String>> onChanged;

  @override
  State<IngredientCheckBottomSheet> createState() =>
      _IngredientCheckBottomSheetState();
}

class _IngredientCheckBottomSheetState extends State<IngredientCheckBottomSheet> {
  late Set<String> _have;

  @override
  void initState() {
    super.initState();
    _have = {...widget.initialHaveKeys};
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.42,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: CFColors.softGray,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (widget.items.isEmpty)
                  const ProgressSectionCard(
                    child: Text('No hay ingredientes disponibles.'),
                  ),
                for (final item in widget.items) ...[
                  ProgressSectionCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _have.contains(item.key),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _have.add(item.key);
                              } else {
                                _have.remove(item.key);
                              }
                            });
                            widget.onChanged(_have);
                          },
                        ),
                        Expanded(
                          child: Text(
                            item.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
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
      },
    );
  }
}
