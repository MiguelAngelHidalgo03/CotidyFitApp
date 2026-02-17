import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'progress_section_card.dart';

class ProgressInsight {
  final IconData icon;
  final String title;
  final String description;

  const ProgressInsight({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class ProgressInsightsSection extends StatelessWidget {
  const ProgressInsightsSection({super.key, required this.insights});

  final List<ProgressInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (var i = 0; i < insights.length; i++) ...[
          _InsightCard(insight: insights[i]),
          if (i != insights.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final ProgressInsight insight;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Icon(insight.icon, color: CFColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(insight.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
