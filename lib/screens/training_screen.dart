import 'package:flutter/material.dart';

import '../widgets/training/training_entry_card.dart';
import '../widgets/training/training_premium_card.dart';
import 'explore_workouts_screen.dart';
import 'my_plan_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  void _openMyPlan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyPlanScreen()),
    );
  }

  void _openExplore() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExploreWorkoutsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              Text(
                'Elige una opción',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              TrainingEntryCard(
                title: 'Mi Plan',
                subtitle: 'Organiza tu semana y asigna rutinas.',
                icon: Icons.event_note_outlined,
                onTap: _openMyPlan,
              ),
              const SizedBox(height: 12),
              TrainingEntryCard(
                title: 'Explorar entrenamientos',
                subtitle: 'Filtra por lugar, objetivo, dificultad y duración.',
                icon: Icons.search_outlined,
                onTap: _openExplore,
              ),
              const SizedBox(height: 18),
              Text('Premium', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const TrainingPremiumCard(),
              const SizedBox(height: 10),
              Text(
                'Tip: completa un entrenamiento para ganar +${20} CF.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
