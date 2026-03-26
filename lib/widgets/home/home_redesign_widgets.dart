import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/home_dashboard_service.dart';

class DynamicHeroBlock extends StatelessWidget {
  const DynamicHeroBlock({
    super.key,
    required this.now,
    required this.onAction,
    required this.showMoodNudge,
  });

  final DateTime now;
  final ValueChanged<String> onAction;
  final bool showMoodNudge;

  @override
  Widget build(BuildContext context) {
    final hour = now.hour;
    final isMorning = hour >= 5 && hour <= 11;
    final isDay = hour >= 12 && hour <= 19;

    final title = isMorning
        ? '¿Cómo te despertaste hoy?'
        : isDay
            ? '¿Qué quieres hacer ahora?'
            : '¿Qué quieres hacer antes de dormir?';

    final actions = isMorning
        ? const [
            ('Desayunar saludable', 'eat_better'),
            ('Entrenar', 'train'),
            ('Planificar el día', 'organize_week'),
          ]
        : isDay
            ? const [
                ('Entrenar', 'train'),
                ('Comer mejor', 'eat_better'),
                ('Caminar', 'walk'),
                ('Organizar semana', 'organize_week'),
              ]
            : const [
                ('Meditar 5 min', 'meditate'),
                ('Estiramientos', 'stretch'),
                ('Revisar progreso', 'progress'),
              ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          if (showMoodNudge) ...[
            const SizedBox(height: 8),
            Text(
              'Completa tu mood diario para personalizar mejor tu plan.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in actions)
                FilledButton.tonal(
                  onPressed: () => onAction(action.$2),
                  child: Text(action.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MoodMiniBlock extends StatefulWidget {
  const MoodMiniBlock({
    super.key,
    required this.answeredToday,
    required this.summary,
    required this.onTap,
  });

  final bool answeredToday;
  final String summary;
  final VoidCallback onTap;

  @override
  State<MoodMiniBlock> createState() => _MoodMiniBlockState();
}

class _MoodMiniBlockState extends State<MoodMiniBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    if (!widget.answeredToday) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MoodMiniBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.answeredToday) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = widget.answeredToday ? 0.0 : (0.25 + (_controller.value * 0.45));
        return InkWell(
          onTap: widget.onTap,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CFColors.surface,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(
                color: widget.answeredToday
                    ? CFColors.softGray
                    : CFColors.primary.withValues(alpha: alpha),
                width: widget.answeredToday ? 1.2 : 1.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mood_outlined,
                  color: widget.answeredToday ? CFColors.primary : CFColors.primaryDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Cómo te sientes hoy?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.answeredToday ? widget.summary : 'Tócalo para registrar tu mood diario',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CalendarStreakCfBlock extends StatelessWidget {
  const CalendarStreakCfBlock({
    super.key,
    required this.days,
    required this.streak,
    required this.cfScore,
  });

  final List<HomeDayStat> days;
  final int streak;
  final int cfScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tu semana',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _Tag(icon: Icons.local_fire_department_outlined, label: '$streak días'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in days)
                Column(
                  children: [
                    Text(d.dayLabel, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: d.completed
                            ? CFColors.primary.withValues(alpha: 0.12)
                            : CFColors.background,
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(
                          color: d.completed ? CFColors.primary : CFColors.softGray,
                        ),
                      ),
                      child: Icon(
                        d.completed ? Icons.check : Icons.remove,
                        size: 18,
                        color: d.completed ? CFColors.primary : CFColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_outlined, color: CFColors.primary),
                const SizedBox(width: 10),
                Text(
                  'CF Score',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '$cfScore',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WaterStepsRings extends StatelessWidget {
  const WaterStepsRings({
    super.key,
    required this.waterMl,
    required this.steps,
    required this.onWaterTap,
    required this.onStepsTap,
  });

  final int waterMl;
  final int steps;
  final VoidCallback onWaterTap;
  final VoidCallback onStepsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RingCard(
            title: 'Agua',
            valueLabel: '$waterMl ml',
            progress: (waterMl / 2000).clamp(0.0, 1.0).toDouble(),
            onTap: onWaterTap,
            icon: Icons.water_drop_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RingCard(
            title: 'Pasos',
            valueLabel: '$steps',
            progress: (steps / 8000).clamp(0.0, 1.0).toDouble(),
            onTap: onStepsTap,
            icon: Icons.directions_walk_outlined,
          ),
        ),
      ],
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({
    required this.title,
    required this.valueLabel,
    required this.progress,
    required this.onTap,
    required this.icon,
  });

  final String title;
  final String valueLabel;
  final double progress;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CFColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: CFColors.softGray),
        ),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) {
                return SizedBox(
                  width: 82,
                  height: 82,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        backgroundColor: CFColors.softGray,
                        color: CFColors.primary,
                      ),
                      Icon(icon, color: CFColors.primary),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
            Text(valueLabel, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class GoalsBlock extends StatelessWidget {
  const GoalsBlock({
    super.key,
    required this.dailyProgress,
    required this.weekly,
    required this.weeklyStreak,
  });

  final double dailyProgress;
  final WeeklyGoalsProgress weekly;
  final int weeklyStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meta diaria', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Completa acciones clave del día', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: dailyProgress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: CFColors.softGray,
              valueColor: const AlwaysStoppedAnimation(CFColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Meta semanal', style: Theme.of(context).textTheme.titleLarge),
              ),
              _Tag(icon: Icons.repeat_outlined, label: 'Racha: $weeklyStreak'),
            ],
          ),
          const SizedBox(height: 8),
          _GoalLine(label: 'Entrenar 3x/semana', done: weekly.trainingDays, target: 3),
          _GoalLine(label: 'Caminar 6000 pasos diarios', done: weekly.stepsDays6000, target: 7),
          _GoalLine(label: 'Comer saludable 3 días', done: weekly.healthyEatingDays, target: 3),
          _GoalLine(label: 'Meditar 2 días', done: weekly.meditationDays, target: 2),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: weekly.progress,
              minHeight: 9,
              backgroundColor: CFColors.softGray,
              valueColor: const AlwaysStoppedAnimation(CFColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.label, required this.done, required this.target});

  final String label;
  final int done;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text('$done/$target', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class WeeklyChallengeBlock extends StatelessWidget {
  const WeeklyChallengeBlock({super.key, required this.challenge});

  final WeeklyChallengeData challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reto semanal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(challenge.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(challenge.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: challenge.progress,
              minHeight: 10,
              backgroundColor: CFColors.softGray,
              valueColor: const AlwaysStoppedAnimation(CFColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${challenge.progressValue}/${challenge.targetValue}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              _Tag(icon: Icons.workspace_premium_outlined, label: '+${challenge.rewardCfBonus} CF · semana'),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickSummaryCard extends StatelessWidget {
  const QuickSummaryCard({
    super.key,
    required this.weekly,
    required this.onTap,
  });

  final WeeklyGoalsProgress weekly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CFColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: CFColors.softGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu progreso esta semana', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: CustomPaint(
                painter: _MiniChartPainter(weekly.progress),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Ver detalle en Progreso', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  _MiniChartPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CFColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = CFColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final path = Path();
    final curve = Path();

    final base = size.height - 10;
    final amp = 20 + (progress.clamp(0, 1) * 20);
    for (var i = 0; i <= 5; i++) {
      final x = (size.width / 5) * i;
      final y = base - math.sin((i / 5) * math.pi) * amp;
      if (i == 0) {
        path.moveTo(x, y);
        curve.moveTo(x, y);
      } else {
        curve.lineTo(x, y);
      }
    }

    path
      ..addPath(curve, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, p);
    canvas.drawPath(curve, line);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class HabitsSection extends StatelessWidget {
  const HabitsSection({
    super.key,
    required this.habits,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<HabitItem> habits;
  final VoidCallback onAdd;
  final ValueChanged<HabitItem> onEdit;
  final ValueChanged<HabitItem> onDelete;
  final void Function(HabitItem habit, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Text('Hábitos', style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text('Estilo Habitica', style: Theme.of(context).textTheme.bodyMedium),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Crear hábito'),
            ),
          ),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No tienes hábitos para hoy.'),
            ),
          for (final habit in habits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: habit.isCompletedToday,
                onChanged: (v) => onToggle(habit, v ?? false),
              ),
              title: Text(habit.name),
              subtitle: Text('+${habit.cfReward} CF'),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    onPressed: () => onEdit(habit),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => onDelete(habit),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TasksSection extends StatelessWidget {
  const TasksSection({
    super.key,
    required this.tasks,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<TaskItem> tasks;
  final VoidCallback onAdd;
  final ValueChanged<TaskItem> onEdit;
  final ValueChanged<TaskItem> onDelete;
  final void Function(TaskItem task, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(),
        title: Text('Tareas', style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text('Separado de hábitos', style: Theme.of(context).textTheme.bodyMedium),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Añadir tarea'),
            ),
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No hay tareas pendientes.'),
            ),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: task.completed,
                onChanged: (v) => onToggle(task, v ?? false),
              ),
              title: Text(task.title),
              subtitle: Text(_taskSubtitle(task)),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    onPressed: () => onEdit(task),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => onDelete(task),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _taskSubtitle(TaskItem task) {
    final due = task.dueDate;
    final dueText = due == null
        ? 'Sin fecha'
        : '${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}';
    return '$dueText · +${task.cfReward} CF · ${task.notificationEnabled ? '🔔' : '🔕'}';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CFColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CFColors.primary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
