import 'package:flutter/material.dart';

import '../core/theme.dart';

class DailyOptionTile extends StatelessWidget {
  const DailyOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? context.cfTextPrimary : context.cfTextSecondary;

    return Card(
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: enabled ? () => onChanged(!selected) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? onChanged : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
