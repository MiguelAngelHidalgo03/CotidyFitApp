import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/message_model.dart';
import '../../models/workout.dart';
import '../../screens/workout_detail_screen.dart';
import '../../screens/nutrition/recipe_detail_screen.dart';
import '../../services/workout_service.dart';
import 'community_avatar.dart';
import '../progress/progress_section_card.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.avatarKeySeed,
    this.avatarLabel,
    this.showTimestamp = true,
  });

  final MessageModel message;
  final bool showAvatar;
  final String? avatarKeySeed;
  final String? avatarLabel;
  final bool showTimestamp;

  String? _readString(Object? v) {
    if (v is! String) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  int? _readInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  bool? _readBool(Object? v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return null;
  }

  List<Map<String, Object?>> _readMapList(Object? v) {
    if (v is! List) return const <Map<String, Object?>>[];
    final out = <Map<String, Object?>>[];
    for (final raw in v) {
      if (raw is Map) {
        out.add(raw.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Future<void> _showDetailSheet(
    BuildContext context, {
    required String title,
    required Widget child,
  }) async {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.70;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ProgressSectionCard(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWorkoutDetail(
    BuildContext context,
    Map<String, Object?> share,
  ) async {
    final workoutId = _readString(share['workoutId']);
    final workoutName = _readString(share['workoutName']);

    final service = WorkoutService();
    await service.ensureLoaded();

    Workout? workout;
    if (workoutId != null) {
      workout = service.getWorkoutById(workoutId);
    }

    if (workout == null && workoutName != null) {
      final wanted = workoutName.toLowerCase();
      for (final w in service.getAllWorkouts()) {
        if (w.name.trim().toLowerCase() == wanted) {
          workout = w;
          break;
        }
      }
    }

    if (workout == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la rutina.')),
      );
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: workout!)),
    );
  }

  Future<void> _openAchievementDetail(
    BuildContext context,
    Map<String, Object?> share,
  ) async {
    final title = _readString(share['title']) ?? 'Logro';
    final desc = _readString(share['description']) ?? '';
    final unlocked = _readBool(share['unlocked']) ?? false;
    final progress = (_readInt(share['progress']) ?? 0).clamp(0, 1 << 30);
    final target = (_readInt(share['target']) ?? 0).clamp(0, 1 << 30);
    final pct = (_readInt(share['pct']) ?? (unlocked ? 100 : 0)).clamp(0, 100);

    final ratio = (target <= 0) ? 0.0 : (progress / target).clamp(0.0, 1.0);
    final status = unlocked ? 'Desbloqueado' : 'En progreso';

    await _showDetailSheet(
      context,
      title: 'Logro · $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.trim().isNotEmpty) ...[
            Text(desc, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: CFColors.softGray,
              valueColor: const AlwaysStoppedAnimation<Color>(CFColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            target > 0 ? '$progress/$target · $pct%' : status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CFColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            status,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _openDaySummaryDetail(
    BuildContext context,
    Map<String, Object?> share,
  ) async {
    final label = _readString(share['label']);
    final dateKey = _readString(share['dateKey']);
    final summary = _readString(share['summary']) ?? message.text;

    final titleParts = <String>['Resumen del día'];
    if (label != null) titleParts.add(label);
    final title = titleParts.join(' · ');

    await _showDetailSheet(
      context,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateKey != null && (label == null || label != dateKey)) ...[
            Text(
              dateKey,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CFColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(summary, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Future<void> _openStreaksDetail(
    BuildContext context,
    Map<String, Object?> share,
  ) async {
    final current = (_readInt(share['currentStreak']) ?? 0).clamp(0, 36500);
    final best = (_readInt(share['maxStreak']) ?? 0).clamp(0, 36500);
    final streakTitle = _readString(share['streakTitle']) ?? 'Racha personalizada';
    final summary = _readString(share['summary']) ?? message.text;

    await _showDetailSheet(
      context,
      title: streakTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text(
            'Racha actual: $current días',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Racha máx: $best días',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecipeDetail(BuildContext context, String recipeId) async {
    final id = recipeId.trim();
    if (id.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
    );
  }

  Future<void> _openCustomMealDetail(
    BuildContext context,
    Map<String, Object?> customMealJson, {
    String? titlePrefix,
  }) async {
    final name =
        _readString(customMealJson['nombre']) ?? 'Comida personalizada';
    final kcal = (_readInt(customMealJson['calorias']) ?? 0).clamp(0, 200000);
    final p = (_readInt(customMealJson['proteinas']) ?? 0).clamp(0, 20000);
    final c = (_readInt(customMealJson['carbohidratos']) ?? 0).clamp(0, 20000);
    final g = (_readInt(customMealJson['grasas']) ?? 0).clamp(0, 20000);
    final foods = _readMapList(customMealJson['listaAlimentos']);

    final title = ((titlePrefix ?? '').trim().isEmpty)
        ? name
        : '$titlePrefix · $name';

    await _showDetailSheet(
      context,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$kcal kcal · P ${p}g · C ${c}g · G ${g}g',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (foods.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Alimentos',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final f in foods) ...[
              Text(
                '• ${_readString(f['name']) ?? 'Alimento'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openDietMealDetail(
    BuildContext context, {
    required Map<String, Object?> share,
    required Map<String, Object?> meal,
  }) async {
    final rootContext = context;
    final dayLabel = _readString(share['label']);
    final dateKey = _readString(share['dateKey']);
    final mealLabel = _readString(meal['label']) ?? 'Comida';

    final titleParts = <String>['Dieta'];
    if (dayLabel != null) titleParts.add(dayLabel);
    titleParts.add(mealLabel);

    final recipes = _readMapList(meal['recipes']);
    final customMeals = _readMapList(meal['customMeals']);

    await _showDetailSheet(
      context,
      title: titleParts.join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateKey != null && (dayLabel == null || dayLabel != dateKey)) ...[
            Text(
              dateKey,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CFColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (recipes.isEmpty && customMeals.isEmpty)
            Text(
              'Sin registros en esta comida.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            if (recipes.isNotEmpty) ...[
              Text(
                'Recetas',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final r in recipes) ...[
                Builder(
                  builder: (context) {
                    final rid = _readString(r['id']);
                    final name = _readString(r['name']);
                    final label = (name == null || name.trim().isEmpty)
                        ? 'Receta'
                        : name;

                    if (rid == null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '• $label',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }

                    return InkWell(
                      onTap: () async {
                        Navigator.of(rootContext).pop();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 140),
                        );
                        if (!rootContext.mounted) return;
                        await _openRecipeDetail(rootContext, rid);
                      },
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              color: CFColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              'Abrir',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: CFColors.textSecondary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right,
                              color: CFColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
            if (customMeals.isNotEmpty) ...[
              Text(
                'Comidas personalizadas',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final cm in customMeals) ...[
                Builder(
                  builder: (context) {
                    final name =
                        _readString(cm['nombre']) ?? 'Comida personalizada';
                    return InkWell(
                      onTap: () async {
                        Navigator.of(rootContext).pop();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 140),
                        );
                        if (!rootContext.mounted) return;
                        await _openCustomMealDetail(
                          rootContext,
                          cm,
                          titlePrefix: 'Dieta · $mealLabel',
                        );
                      },
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.restaurant_menu,
                              color: CFColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              'Abrir',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: CFColors.textSecondary,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right,
                              color: CFColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openShare(BuildContext context) async {
    final share = message.share;
    if (share == null || share.isEmpty) return;
    switch (message.type) {
      case MessageType.text:
        return;
      case MessageType.routine:
        await _openWorkoutDetail(context, share);
        return;
      case MessageType.achievement:
        await _openAchievementDetail(context, share);
        return;
      case MessageType.daySummary:
        await _openDaySummaryDetail(context, share);
        return;
      case MessageType.streaks:
        await _openStreaksDetail(context, share);
        return;
      case MessageType.diet:
        // Diet messages have per-meal taps; no single action.
        return;
    }
  }

  String _timeLabel(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    final bg = isMine ? CFColors.primary : CFColors.softGray;
    final fg = isMine ? Colors.white : CFColors.textPrimary;

    final ts = _timeLabel(message.createdAtMs);
    final showIncomingAvatar = showAvatar && !isMine;

    final share = message.share;
    final hasShare =
        message.type != MessageType.text && share != null && share.isNotEmpty;

    final prefix = switch (message.type) {
      MessageType.text => null,
      MessageType.routine => 'Rutina',
      MessageType.achievement => 'Logro',
      MessageType.daySummary => 'Resumen del día',
      MessageType.diet => 'Dieta',
      MessageType.streaks => 'Rachas',
    };

    String? ctaLabel() {
      if (!hasShare) return null;
      switch (message.type) {
        case MessageType.routine:
          return 'Ver rutina';
        case MessageType.achievement:
          return 'Ver logro';
        case MessageType.daySummary:
          return 'Ver resumen';
        case MessageType.streaks:
          return 'Ver rachas';
        case MessageType.diet:
          return 'Toca una comida para ver el detalle';
        case MessageType.text:
          return null;
      }
    }

    Widget bubble() {
      final borderRadius = BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isMine ? 16 : 6),
        bottomRight: Radius.circular(isMine ? 6 : 16),
      );

      final hintColor = isMine
          ? Colors.white.withValues(alpha: 0.88)
          : CFColors.textSecondary;
      final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: hintColor,
        fontWeight: FontWeight.w900,
      );

      final isDietShare = hasShare && message.type == MessageType.diet;
      final meals = isDietShare
          ? _readMapList(share['meals'])
          : const <Map<String, Object?>>[];

      final baseHint = ctaLabel();
      final hint = (isDietShare && meals.isEmpty) ? null : baseHint;

      Widget messageTextWidget() {
        final raw = message.text.trimRight();
        final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: fg,
          height: 1.25,
          fontWeight: isMine ? FontWeight.w600 : FontWeight.w500,
        );

        if (!hasShare) {
          return Text(raw, style: baseStyle);
        }

        final lines = raw.split('\n');
        if (lines.length <= 1) {
          return Text(raw, style: baseStyle);
        }

        final headline = lines.first.trim();
        final body = lines.skip(1).join('\n').trim();

        final headlineStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: fg,
          height: 1.15,
          fontWeight: FontWeight.w900,
        );
        final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: fg,
          height: 1.25,
          fontWeight: isMine ? FontWeight.w800 : FontWeight.w700,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: headlineStyle ?? baseStyle),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body, style: bodyStyle),
            ],
          ],
        );
      }

      final bubbleBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null) ...[
            Text(
              prefix,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.92)
                    : CFColors.textSecondary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
          ],
          messageTextWidget(),
          if (isDietShare && meals.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final meal in meals) ...[
              Builder(
                builder: (context) {
                  final label = _readString(meal['label']) ?? 'Comida';
                  final count = (_readInt(meal['count']) ?? 0).clamp(0, 999);
                  return InkWell(
                    onTap: () =>
                        _openDietMealDetail(context, share: share, meal: meal),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$label ($count)',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          if (hint != null)
                            Text(
                              'Abrir',
                              style: hintStyle?.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          if (hint != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: hintColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
          if (hint != null && isDietShare && meals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(hint, style: hintStyle),
          ],
          if (hint != null && !isDietShare) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(hint, style: hintStyle),
                const Spacer(),
                Icon(Icons.chevron_right, size: 18, color: hintColor),
              ],
            ),
          ],
        ],
      );

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: borderRadius,
                border: isMine ? null : Border.all(color: CFColors.softGray),
              ),
              child: hasShare && !isDietShare
                  ? InkWell(
                      onTap: () => _openShare(context),
                      borderRadius: borderRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: bubbleBody,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: bubbleBody,
                    ),
            ),
          ),
        ),
      );
    }

    Widget timestamp() {
      if (!showTimestamp) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(
          left: showIncomingAvatar ? 44 : 0,
          right: isMine ? 6 : 0,
          top: 0,
          bottom: 2,
        ),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            ts,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isMine ? CFColors.textSecondary : CFColors.textSecondary,
            ),
          ),
        ),
      );
    }

    Widget content() {
      final bubbleColumn = Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [bubble(), timestamp()],
      );

      if (!showIncomingAvatar) return bubbleColumn;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CommunityAvatar(
            keySeed: (avatarKeySeed ?? message.senderId).trim().isEmpty
                ? message.senderId
                : avatarKeySeed!,
            label: (avatarLabel ?? message.senderName).trim().isEmpty
                ? message.senderName
                : avatarLabel!,
            size: 34,
          ),
          const SizedBox(width: 10),
          Flexible(child: bubbleColumn),
        ],
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: content(),
    );
  }
}
