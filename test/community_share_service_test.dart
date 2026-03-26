import 'package:cotidyfitapp/models/achievement_catalog_item.dart';
import 'package:cotidyfitapp/models/message_model.dart';
import 'package:cotidyfitapp/models/user_achievement.dart';
import 'package:cotidyfitapp/services/achievements_service.dart';
import 'package:cotidyfitapp/services/community_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAchievementsService extends AchievementsService {
  _FakeAchievementsService(this.items);

  final List<AchievementViewItem> items;

  @override
  Future<List<AchievementViewItem>> getAchievementsForCurrentUser() async {
    return items;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityShareService external drafts', () {
    const daySummaryOption = CommunityShareOption(
      id: 'day_20260314',
      title: 'Hoy',
      subtitle:
          'CF 72 · Entreno HIIT 24 min · 8340 pasos · 1.8 L agua · 2/3 comidas',
      payload:
          '¡Observa mi resumen de hoy!\nCF 72 · Entreno HIIT 24 min · 8340 pasos · 1.8 L agua · 2/3 comidas',
      share: {
        'label': 'Hoy',
        'summary':
            'CF 72 · Entreno HIIT 24 min · 8340 pasos · 1.8 L agua · 2/3 comidas',
        'cfPoints': 72,
        'workoutMinutes': 24,
        'workoutLabel': 'HIIT 24 min',
        'workoutName': 'HIIT Express',
        'steps': 8340,
        'waterLiters': 1.8,
        'healthyMeals': 2,
        'moodIcon': '🙂',
        'moodValue': 4,
      },
    );

    const streakOption = CommunityShareOption(
      id: 'streaks',
      title: 'Rachas',
      subtitle: 'Racha de Mix flexible: 12 días · Mejor: 21 días',
      payload:
          '¡Observa mis rachas!\nRacha de Mix flexible: 12 días · Mejor: 21 días',
      share: {
        'summary': 'Racha de Mix flexible: 12 días · Mejor: 21 días',
        'streakTitle': 'Mix flexible',
        'currentStreak': 12,
        'maxStreak': 21,
      },
    );

    test('builds WhatsApp text from external template file', () async {
      final service = CommunityShareService(
        publicPromoUrl: 'https://example.com/cotidyfit',
      );

      final draft = await service.composeExternalShareDraft(
        type: MessageType.daySummary,
        option: daySummaryOption,
        target: CommunityExternalShareTarget.whatsappChat,
      );

      expect(draft.subject, 'CotidyFit · Resumen');
      expect(draft.text, contains('Mi día en CotidyFit 💪'));
      expect(draft.text, contains('CF 72'));
      expect(draft.text, contains('Entreno: HIIT 24 min'));
      expect(draft.text, contains('Pasos: 8.340'));
      expect(draft.text, contains('Agua: 1.8 L'));
      expect(draft.text, contains('example.com'));
      expect(draft.shortPhrase, contains('No todos los días son perfectos'));
    });

    test('uses the post/reel template for Instagram post', () async {
      final service = CommunityShareService(
        publicPromoUrl: 'https://example.com/cotidyfit',
      );

      final draft = await service.composeExternalShareDraft(
        type: MessageType.daySummary,
        option: daySummaryOption,
        target: CommunityExternalShareTarget.instagramPost,
      );

      expect(draft.text, contains('Mi día en CotidyFit 💪'));
      expect(draft.text, contains('Comidas: 2/3'));
      expect(draft.text, contains('example.com'));
      expect(draft.text, isNot(contains('#CotidyFit')));
    });

    test('builds streak template with current and best values', () async {
      final service = CommunityShareService(
        publicPromoUrl: 'https://example.com/cotidyfit',
      );

      final draft = await service.composeExternalShareDraft(
        type: MessageType.streaks,
        option: streakOption,
        target: CommunityExternalShareTarget.tiktok,
      );

      expect(draft.subject, 'CotidyFit · Rachas');
      expect(draft.text, contains('Mi racha en CotidyFit 🔥'));
      expect(draft.text, contains('Racha actual: 12 días'));
      expect(draft.text, contains('Mejor racha: 21 días'));
      expect(draft.text, isNot(contains('Foco:')));
      expect(draft.text, isNot(contains('Mix flexible')));
      expect(draft.text, contains('example.com'));
    });

    test('prepares a rendered visual card image', () async {
      final service = CommunityShareService(
        publicPromoUrl: 'https://example.com/cotidyfit',
      );

      final prepared = await service.prepareExternalShare(
        type: MessageType.daySummary,
        option: daySummaryOption,
        target: CommunityExternalShareTarget.whatsappChat,
      );

      expect(prepared.draft.text, contains('Mi día en CotidyFit 💪'));
      expect(prepared.imageName, 'cotidyfit_daySummary_day_20260314.png');
      expect(prepared.imageBytes, isNotEmpty);
    });

    test('replaces missing share values with readable fallbacks', () async {
      final service = CommunityShareService(
        publicPromoUrl: 'https://example.com/cotidyfit',
      );

      const missingDataOption = CommunityShareOption(
        id: 'day_missing',
        title: 'Hoy',
        subtitle: 'Sin datos',
        payload: 'Mi día en CotidyFit 💪\nSin datos',
        share: {
          'label': 'Hoy',
          'summary': 'Sin datos',
          'cfPoints': 0,
          'workoutMinutes': 0,
          'workoutLabel': '',
          'workoutName': '',
          'steps': 0,
          'waterLiters': 0.0,
          'healthyMeals': 0,
        },
      );

      final draft = await service.composeExternalShareDraft(
        type: MessageType.daySummary,
        option: missingDataOption,
        target: CommunityExternalShareTarget.whatsappChat,
      );

      expect(draft.text, contains('Entreno: Hoy no has entrenado'));
      expect(draft.text, contains('Pasos: Todavía no has dado pasos'));
      expect(draft.text, contains('Agua: Todavía no has bebido agua'));
      expect(draft.text, isNot(contains('—')));
      expect(draft.text, isNot(contains('Sin datos')));
    });
  });

  group('CommunityShareService achievement options', () {
    test('only expose unlocked achievements', () async {
      final service = CommunityShareService(
        achievements: _FakeAchievementsService([
          AchievementViewItem(
            catalog: const AchievementCatalogItem(
              id: 'locked_achievement',
              title: 'Aun en progreso',
              description: 'No deberia salir.',
              icon: 'emoji_events_outlined',
              category: 'progreso',
              conditionType: 'workouts_completed',
              conditionValue: 10,
            ),
            user: const UserAchievement(
              achievementId: 'locked_achievement',
              unlocked: false,
              unlockedAt: null,
              progress: 4,
              visible: true,
            ),
          ),
          AchievementViewItem(
            catalog: const AchievementCatalogItem(
              id: 'done_achievement',
              title: 'Logro hecho',
              description: 'Este si debe salir.',
              icon: 'emoji_events_outlined',
              category: 'progreso',
              conditionType: 'workouts_completed',
              conditionValue: 1,
            ),
            user: UserAchievement(
              achievementId: 'done_achievement',
              unlocked: true,
              unlockedAt: DateTime(2026, 3, 12),
              progress: 1,
              visible: true,
            ),
          ),
        ]),
      );

      final options = await service.getShareOptions(
        type: MessageType.achievement,
      );

      expect(options, hasLength(1));
      expect(options.first.id, 'ach_done_achievement');
      expect(options.first.title, 'Logro hecho');
      expect(options.first.payload, contains('Nuevo logro en CotidyFit 🏆'));
      expect(options.first.share?['difficulty'], 'Fácil');
      expect(options.first.share?['achievementType'], 'Progreso');
      expect(options.first.share?['rarityLabel'], 'Buen comienzo');
    });
  });
}
