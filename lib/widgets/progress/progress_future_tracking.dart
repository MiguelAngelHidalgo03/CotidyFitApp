import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'progress_section_card.dart';

class ProgressFutureTracking extends StatelessWidget {
  const ProgressFutureTracking({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seguimiento inteligente', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.12,
          children: const [
            _FutureCard(title: 'Consistencia semanal', icon: Icons.calendar_view_week_outlined),
            _FutureCard(title: 'Energía prom. semanal', icon: Icons.bolt_outlined),
            _FutureCard(title: 'Sueño prom. semanal', icon: Icons.nights_stay_outlined),
            _FutureCard(title: 'Estrés prom. semanal', icon: Icons.self_improvement_outlined),
            _FutureCard(title: 'Hidratación prom.', icon: Icons.water_drop_outlined),
            _FutureCard(title: 'Movimiento prom.', icon: Icons.directions_walk_outlined),
          ],
        ),
      ],
    );
  }
}

class _FutureCard extends StatelessWidget {
  const _FutureCard({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: CFColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const Spacer(),
          Text(
            '—',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text('próximamente', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
