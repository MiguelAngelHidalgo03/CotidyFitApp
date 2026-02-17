import 'package:flutter/material.dart';

import '../../core/theme.dart';

class HomeExtrasSection extends StatelessWidget {
  const HomeExtrasSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _FeelingsRow(),
        SizedBox(height: 18),
        _QuickActivityGrid(),
        SizedBox(height: 18),
        _AchievementsCard(),
        SizedBox(height: 18),
        _PremiumPromoCard(),
        SizedBox(height: 18),
        _MotivationalFooter(),
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

class _FeelingsRow extends StatelessWidget {
  const _FeelingsRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('¿Cómo te sientes hoy?'),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _MiniFeelingCard(title: 'Energía', icon: Icons.bolt, options: ['Baja', 'Media', 'Alta']),
              SizedBox(width: 12),
              _MiniFeelingCard(title: 'Ánimo', icon: Icons.sentiment_satisfied_alt, options: ['Bajo', 'Ok', 'Alto']),
              SizedBox(width: 12),
              _MiniFeelingCard(title: 'Estrés', icon: Icons.self_improvement, options: ['Bajo', 'Medio', 'Alto']),
              SizedBox(width: 12),
              _MiniFeelingCard(title: 'Sueño', icon: Icons.nightlight_round, options: ['Mal', 'Ok', 'Bien']),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFeelingCard extends StatelessWidget {
  const _MiniFeelingCard({
    required this.title,
    required this.icon,
    required this.options,
  });

  final String title;
  final IconData icon;
  final List<String> options;

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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            options.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: CFColors.textSecondary,
                ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              border: Border.all(color: CFColors.primary.withValues(alpha: 0.14)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              'Toca para registrar (próximamente)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CFColors.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActivityGrid extends StatelessWidget {
  const _QuickActivityGrid();

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
          childAspectRatio: 1.35,
          children: const [
            _MiniMetricCard(title: 'Pasos', icon: Icons.directions_walk, value: '—'),
            _MiniMetricCard(title: 'Agua', icon: Icons.water_drop_outlined, value: '—'),
            _MiniMetricCard(title: 'Comidas', icon: Icons.restaurant_outlined, value: '—'),
            _MiniMetricCard(title: 'Min activos', icon: Icons.timer_outlined, value: '—'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Solo visual (sin seguimiento todavía).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: CFColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard();

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
              Expanded(child: Text('Logros', style: Theme.of(context).textTheme.titleLarge)),
              TextButton(
                onPressed: null,
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
                child: const Icon(Icons.emoji_events_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Último logro desbloqueado',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aún no hay logros',
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
          FilledButton(
            onPressed: null,
            child: const Text('Próximamente'),
          ),
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
