import 'package:cotidyfitapp/models/user_profile.dart';
import 'package:cotidyfitapp/services/personalized_streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PersonalizedStreakService();

  test('single nutrition focus requires meal target', () {
    final profile = UserProfile(
      goal: 'Mejorar habitos',
      streakPreferences: UserStreakPreferences(
        focusAreas: [UserStreakFocusArea.nutrition],
      ),
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(mealsLoggedCount: 2),
      ),
      isFalse,
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(mealsLoggedCount: 3),
      ),
      isTrue,
    );
  });

  test('mix any counts if one selected focus is completed', () {
    final profile = UserProfile(
      goal: 'Mejorar habitos',
      streakPreferences: UserStreakPreferences(
        focusAreas: [
          UserStreakFocusArea.training,
          UserStreakFocusArea.steps,
        ],
        mixMode: UserStreakMixMode.any,
      ),
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(steps: 8000),
      ),
      isTrue,
    );
  });

  test('mix all requires all selected focuses', () {
    final profile = UserProfile(
      goal: 'Mejorar habitos',
      streakPreferences: UserStreakPreferences(
        focusAreas: [
          UserStreakFocusArea.training,
          UserStreakFocusArea.water,
        ],
        mixMode: UserStreakMixMode.all,
      ),
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(workoutCompleted: true),
      ),
      isFalse,
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(
          workoutCompleted: true,
          waterLiters: 2.5,
        ),
      ),
      isTrue,
    );
  });

  test('daily challenge uses workout, water and meditation together', () {
    final profile = UserProfile(
      goal: 'Mejorar habitos',
      streakPreferences: UserStreakPreferences(
        focusAreas: [UserStreakFocusArea.dailyChallenge],
      ),
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(
          workoutCompleted: true,
          waterLiters: 2.0,
          meditationMinutes: 5,
        ),
      ),
      isTrue,
    );

    expect(
      service.isCompletedDay(
        profile: profile,
        snapshot: const PersonalizedStreakDaySnapshot(
          workoutCompleted: true,
          waterLiters: 1.9,
          meditationMinutes: 5,
        ),
      ),
      isFalse,
    );
  });
}
