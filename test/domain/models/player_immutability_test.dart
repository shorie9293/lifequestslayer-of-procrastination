import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';

/// 道標§五#7: Player モデルイミュータブル化の試練（第一段階）。
///
/// 現時点で実装済みの基盤：
/// 1. Player.copyWith — 指定フィールドのみ変更した新インスタンスを返し、元を不変に保つ。
/// 2. TaskStreak のイミュータブル化（final + copyWith）。
/// 3. recordTaskCompletion が TaskStreak.copyWith 経由で更新する。
void main() {
  group('Player.copyWith', () {
    test('指定したフィールドのみ変更し新インスタンスを返す', () {
      final p = Player();
      final p2 = p.copyWith(coins: 100);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p2.coins, 100);
      expect(p.coins, 0, reason: '元インスタンスは不変');
    });

    test('未指定フィールドは元の値を保持する', () {
      final p = Player()
          .copyWith(coins: 10, gems: 20, currentJob: Job.samurai);
      final p2 = p.copyWith(coins: 99);

      expect(p2.gems, 20, reason: '未指定フィールドは保持');
      expect(p2.currentJob, Job.samurai);
      expect(p2.coins, 99);
    });

    test('nullable フィールドを null にクリアできる', () {
      final p = Player().copyWith(equippedTitle: '勇者');
      expect(p.equippedTitle, '勇者');
      final cleared = p.copyWith(equippedTitle: null);
      expect(cleared.equippedTitle, isNull, reason: 'nullでクリア可能');
    });

    test('copyWith後も元インスタンスの全フィールドが不変', () {
      final p = Player()
          .copyWith(coins: 50, gems: 7, currentJob: Job.monk, streakDays: 5);
      final before = p.toJson();
      final _ = p.copyWith(coins: 9999);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
    });
  });

  group('TaskStreak イミュータブル', () {
    test('copyWith は新インスタンスを返し元は不変', () {
      final s = TaskStreak(
          currentStreak: 3, lastCompletedDate: DateTime(2026, 1, 1));
      final s2 = s.copyWith(currentStreak: 4);

      expect(identical(s, s2), isFalse);
      expect(s.currentStreak, 3, reason: '元は不変');
      expect(s2.currentStreak, 4);
      expect(s2.lastCompletedDate, DateTime(2026, 1, 1),
          reason: '未指定フィールドは保持');
    });
  });

  group('アニメーション視聴フラグ final（段階返済第二段）', () {
    test('hasSeenMandalaAnimation は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(hasSeenMandalaAnimation: true);

      expect(identical(p, p2), isFalse);
      expect(p.hasSeenMandalaAnimation, isFalse, reason: '元は不変');
      expect(p2.hasSeenMandalaAnimation, isTrue);
    });

    test('hasSeenReversalAnimation は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(hasSeenReversalAnimation: true);

      expect(identical(p, p2), isFalse);
      expect(p.hasSeenReversalAnimation, isFalse, reason: '元は不変');
      expect(p2.hasSeenReversalAnimation, isTrue);
    });

    test('copyWith後も元インスタンスの視聴フラグは不変のまま', () {
      final p = Player();
      final before = p.toJson();
      final _ = p.copyWith(
          hasSeenMandalaAnimation: true, hasSeenReversalAnimation: true);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
    });
  });
}
