import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/home_remote_content_service.dart';

class HomeTailSection extends StatelessWidget {
  const HomeTailSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PremiumCard(),
        SizedBox(height: 16),
        _MotivationalQuote(),
      ],
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: const Icon(Icons.workspace_premium, color: CFColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Premium',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            'Próximamente',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MotivationalQuote extends StatelessWidget {
  const _MotivationalQuote();

  static const List<String> _fallbackQuotes = <String>[
    'Cada pequeña decisión suma.',
    'Hazlo simple. Hazlo hoy.',
    'Constancia > perfección.',
    'Un paso más también cuenta.',
    'Tu energía se entrena cada día.',
  ];

  static const HomeRemoteContentService _contentService =
      HomeRemoteContentService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _contentService.watchStartQuotes(fallback: _fallbackQuotes),
      initialData: _fallbackQuotes,
      builder: (context, snapshot) {
        final quote = _contentService.quoteForToday(
          snapshot.data ?? _fallbackQuotes,
          DateTime.now(),
        );
        return Text(
          quote.isEmpty ? '' : '“$quote”',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: CFColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }
}
