import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_service.dart';

/// 討伐戦績集計サービス（改善提案 #56）の試練。
void main() {
  DateTime t(int day, [int minute = 0]) => DateTime(2026, 9, day, 9, minute);

  BattleRecord rec(
    String id,
    DateTime at,
    bool victory, {
    int combo = 0,
    int remaining = 0,
  }) =>
      BattleRecord(
        id: id,
        title: '討伐',
        occurredAt: at,
        isVictory: victory,
        comboCount: combo,
        remainingSubTasks: remaining,
      );

  group('summarize', () {
    test('空リストでも例外を投げない', () {
      final s = BattleRecordService.summarize(const []);
      expect(s.total, 0);
      expect(s.wins, 0);
      expect(s.losses, 0);
      expect(s.winRate, 0.0);
      expect(s.winRatePercent, 0);
      expect(s.hasRecords, isFalse);
      expect(s.lastRecord, isNull);
      expect(s.currentWinStreak, 0);
      expect(s.currentLoseStreak, 0);
      expect(s.longestWinStreak, 0);
      expect(s.longestLoseStreak, 0);
    });

    test('勝率・勝敗数を算出する', () {
      final s = BattleRecordService.summarize([
        rec('a', t(1), true),
        rec('b', t(2), true),
        rec('c', t(3), false),
        rec('d', t(4), true),
        rec('e', t(5), false),
      ]);
      expect(s.total, 5);
      expect(s.wins, 3);
      expect(s.losses, 2);
      expect(s.winRate, closeTo(3 / 5, 1e-9));
      expect(s.winRatePercent, 60);
      expect(s.hasRecords, isTrue);
    });

    test('現在の連勝・連敗は新しい方から数える', () {
      final s = BattleRecordService.summarize([
        rec('a', t(1), true),
        rec('b', t(2), true),
        rec('c', t(3), false),
        rec('d', t(4), false),
        rec('e', t(5), false),
      ]);
      expect(s.currentLoseStreak, 3);
      expect(s.currentWinStreak, 0);
      expect(s.longestWinStreak, 2);
      expect(s.longestLoseStreak, 3);
      expect(s.lastRecord!.id, 'e');
    });

    test('最新が勝ちなら currentWinStreak を数える', () {
      final s = BattleRecordService.summarize([
        rec('a', t(1), false),
        rec('b', t(2), true),
        rec('c', t(3), true),
      ]);
      expect(s.currentWinStreak, 2);
      expect(s.currentLoseStreak, 0);
      expect(s.longestWinStreak, 2);
      expect(s.longestLoseStreak, 1);
    });

    test('最長記録は古い方から走査して求める', () {
      // 古→新: 連勝2, 連敗1, 連勝3, 連敗2
      final s = BattleRecordService.summarize([
        rec('a', t(1), true),
        rec('b', t(2), true),
        rec('c', t(3), false),
        rec('d', t(4), true),
        rec('e', t(5), true),
        rec('f', t(6), true),
        rec('g', t(7), false),
        rec('h', t(8), false),
      ]);
      expect(s.longestWinStreak, 3);
      expect(s.longestLoseStreak, 2);
      expect(s.currentWinStreak, 0);
      expect(s.currentLoseStreak, 2);
    });

    test('同時刻は id 昇順で並べる', () {
      final s = BattleRecordService.summarize([
        rec('b', t(1), true),
        rec('a', t(1), false),
      ]);
      // 古→新 = a(負け), b(勝ち) → 現在は連勝1
      expect(s.currentWinStreak, 1);
      expect(s.currentLoseStreak, 0);
      expect(s.lastRecord!.id, 'b');
    });
  });

  group('recent', () {
    test('新しい順に n 件返す', () {
      final out = BattleRecordService.recent([
        rec('a', t(1), true),
        rec('b', t(3), true),
        rec('c', t(2), false),
        rec('d', t(4), false),
      ], 2);
      expect(out.map((r) => r.id).toList(), ['d', 'b']);
    });

    test('n が0以下なら空リスト', () {
      final out = BattleRecordService.recent(
        [rec('a', t(1), true)],
        0,
      );
      expect(out, isEmpty);
      expect(BattleRecordService.recent([rec('a', t(1), true)], -3), isEmpty);
    });

    test('n が総数を超えても全件返す', () {
      final out = BattleRecordService.recent([
        rec('a', t(1), true),
        rec('b', t(2), true),
      ], 99);
      expect(out.length, 2);
      expect(out.first.id, 'b');
    });

    test('同時刻は id 昇順', () {
      final out = BattleRecordService.recent([
        rec('a', t(1), true),
        rec('c', t(1), true),
        rec('b', t(1), true),
      ], 3);
      expect(out.map((r) => r.id).toList(), ['a', 'b', 'c']);
    });
  });

  group('filterByResult', () {
    test('順序を保持して勝ちのみ絞り込む', () {
      final src = [
        rec('a', t(1), true),
        rec('b', t(2), false),
        rec('c', t(3), true),
      ];
      expect(
        BattleRecordService.filterByResult(src, true).map((r) => r.id),
        ['a', 'c'],
      );
      expect(
        BattleRecordService.filterByResult(src, false).map((r) => r.id),
        ['b'],
      );
    });

    test('該当なしは空リスト', () {
      expect(
        BattleRecordService.filterByResult(
          [rec('a', t(1), true)],
          false,
        ),
        isEmpty,
      );
    });
  });

  group('winRateLabel', () {
    test('パーセント形式の文字列を返す', () {
      expect(BattleRecordService.winRateLabel(0.625), '62.5%');
      expect(BattleRecordService.winRateLabel(1.0), '100.0%');
      expect(BattleRecordService.winRateLabel(0.0), '0.0%');
      expect(BattleRecordService.winRateLabel(2 / 3), '66.7%');
    });

    test('範囲外はクランプする', () {
      expect(BattleRecordService.winRateLabel(-0.2), '0.0%');
      expect(BattleRecordService.winRateLabel(1.5), '100.0%');
    });
  });
}
