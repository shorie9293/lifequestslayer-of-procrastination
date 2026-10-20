import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';

void main() {
  group('StreakFreezeState', () {
    test('既定は券0枚・履歴なし', () {
      const s = StreakFreezeState.defaults;
      expect(s.tickets, 0);
      expect(s.grantedMilestones, isEmpty);
      expect(s.history, isEmpty);
    });

    test('JSON往復で内容が保たれる', () {
      final state = StreakFreezeState(
        tickets: 2,
        grantedMilestones: const [7, 14],
        history: [
          StreakFreezeUsage(
            usedAt: DateTime(2026, 10, 18, 9, 30),
            coveredMissedDays: 1,
            keptStreak: 12,
            coveredDates: const ['2026-10-17'],
          ),
        ],
      );
      final restored = StreakFreezeState.fromJson(state.toJson());
      expect(restored, state);
      expect(restored.history.single.keptStreak, 12);
      expect(restored.history.single.coveredDates, ['2026-10-17']);
    });

    test('旧データ（券キーのみ）でも読める', () {
      final s = StreakFreezeState.fromJson({'tickets': 1});
      expect(s.tickets, 1);
      expect(s.grantedMilestones, isEmpty);
      expect(s.history, isEmpty);
    });

    test('破損JSONは既定値へフォールバックし例外を投げない', () {
      expect(StreakFreezeState.fromJson(null), StreakFreezeState.defaults);
      expect(StreakFreezeState.fromJson('broken'), StreakFreezeState.defaults);
      expect(StreakFreezeState.fromJson({'tickets': 'x'}).tickets, 0);
      expect(
        StreakFreezeState.fromJson({
          'tickets': 1,
          'history': [
            {'usedAt': 'not-a-date'},
            {'usedAt': '2026-10-18T00:00:00.000'},
          ],
        }).history.length,
        1,
      );
    });

    test('負の券数は0へ丸める', () {
      expect(StreakFreezeState.fromJson({'tickets': -5}).tickets, 0);
    });
  });

  group('StreakFreezeOffer', () {
    test('値等価（休んだ日付リストを含む）', () {
      const a = StreakFreezeOffer(
          previousStreak: 5, missedDays: 1, missedDateKeys: ['2026-10-17']);
      const b = StreakFreezeOffer(
          previousStreak: 5, missedDays: 1, missedDateKeys: ['2026-10-17']);
      const c = StreakFreezeOffer(
          previousStreak: 5, missedDays: 2, missedDateKeys: ['2026-10-16']);
      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}
