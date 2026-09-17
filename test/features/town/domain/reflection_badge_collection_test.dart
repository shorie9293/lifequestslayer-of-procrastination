import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/reflection_badge.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_badge_collection.dart';

Reflection _r({
  required DateTime date,
  int self = 1,
  QuestRank ai = QuestRank.B,
  String content = 'x',
}) {
  return Reflection(
    id: 'r_${date.millisecondsSinceEpoch}_${self}_$ai',
    taskId: 't1',
    date: date,
    content: content,
    selfDifficulty: self,
    aiDifficulty: ai,
  );
}

Player _player({
  int totalReflections = 0,
  List<String> badges = const [],
}) {
  return Player(totalReflections: totalReflections, reflectionBadges: badges);
}

void main() {
  group('kReflectionBadgeRequirements 分母マッピング', () {
    test('全12バッジの分母が正しい', () {
      expect(kReflectionBadgeRequirements, {
        'first_reflection': 1,
        'reflection_novice': 5,
        'reflection_adept': 20,
        'reflection_sage': 50,
        'reflection_master': 100,
        'first_insight': 1,
        'deep_insight': 1,
        'honest_assessor': 1,
        'streak_3': 3,
        'streak_7': 7,
        'streak_30': 30,
        'self_awareness': 3,
      });
    });

    test('全バッジ定義に分母が存在する', () {
      for (final def in kAllReflectionBadges) {
        expect(kReflectionBadgeRequirements.containsKey(def.id), isTrue,
            reason: '${def.id} の分母が未定義');
      }
      expect(kAllReflectionBadges.length, 12);
    });
  });

  group('build 基本挙動', () {
    test('全12バッジが返る', () {
      final list = ReflectionBadgeCollection.build(player: _player());
      expect(list.length, 12);
    });

    test('reflections == null でも例外を投げない', () {
      expect(
        () => ReflectionBadgeCollection.build(player: _player()),
        returnsNormally,
      );
    });

    test('カウント系の current は totalReflections を使用', () {
      final list = ReflectionBadgeCollection.build(
        player: _player(totalReflections: 7),
      );
      final novice = list.firstWhere((p) => p.def.id == 'reflection_novice');
      expect(novice.current, 7);
      expect(novice.required, 5);
      final master = list.firstWhere((p) => p.def.id == 'reflection_master');
      expect(master.current, 7);
      expect(master.required, 100);
    });

    test('未獲得バッジの isUnlocked は false', () {
      final list = ReflectionBadgeCollection.build(player: _player());
      expect(list.every((p) => !p.isUnlocked), isTrue);
    });

    test('獲得済みバッジの isUnlocked は true', () {
      final list = ReflectionBadgeCollection.build(
        player: _player(badges: ['first_reflection', 'streak_3']),
      );
      expect(
        list.firstWhere((p) => p.def.id == 'first_reflection').isUnlocked,
        isTrue,
      );
      expect(
        list.firstWhere((p) => p.def.id == 'streak_3').isUnlocked,
        isTrue,
      );
      expect(
        list.firstWhere((p) => p.def.id == 'reflection_novice').isUnlocked,
        isFalse,
      );
    });

    test('コンテンツ系バッジは獲得状態で1/0が決まる', () {
      final unlocked = ReflectionBadgeCollection.build(
        player: _player(badges: ['first_insight']),
      );
      expect(
        unlocked.firstWhere((p) => p.def.id == 'first_insight').current,
        1,
      );
      final locked = ReflectionBadgeCollection.build(player: _player());
      expect(
        locked.firstWhere((p) => p.def.id == 'first_insight').current,
        0,
      );
    });
  });

  group('streak算出', () {
    test('3日連続で streak_3 の current が3', () {
      final now = DateTime(2026, 9, 10);
      final reflections = [
        _r(date: now),
        _r(date: now.subtract(const Duration(days: 1))),
        _r(date: now.subtract(const Duration(days: 2))),
      ];
      final list = ReflectionBadgeCollection.build(
        player: _player(),
        reflections: reflections,
      );
      expect(list.firstWhere((p) => p.def.id == 'streak_3').current, 3);
    });

    test('連続が途切れると途切れ以前は数えない', () {
      final now = DateTime(2026, 9, 10);
      final reflections = [
        _r(date: now),
        _r(date: now.subtract(const Duration(days: 1))),
        _r(date: now.subtract(const Duration(days: 5))),
      ];
      final list = ReflectionBadgeCollection.build(
        player: _player(),
        reflections: reflections,
      );
      expect(list.firstWhere((p) => p.def.id == 'streak_3').current, 2);
    });

    test('streakはrequiredでクランプされる', () {
      final now = DateTime(2026, 9, 10);
      final reflections = List.generate(
        8,
        (i) => _r(date: now.subtract(Duration(days: i))),
      );
      final list = ReflectionBadgeCollection.build(
        player: _player(),
        reflections: reflections,
      );
      // 連続8日 → streak_7 は分母で頭打ち(7)、streak_30 は実測値(8)。
      expect(list.firstWhere((p) => p.def.id == 'streak_7').current, 7);
      expect(list.firstWhere((p) => p.def.id == 'streak_30').current, 8);
    });

    test('streakは分母を超えない（35日連続でも30で頭打ち）', () {
      final now = DateTime(2026, 9, 10);
      final reflections = List.generate(
        35,
        (i) => _r(date: now.subtract(Duration(days: i))),
      );
      final list = ReflectionBadgeCollection.build(
        player: _player(),
        reflections: reflections,
      );
      expect(list.firstWhere((p) => p.def.id == 'streak_3').current, 3);
      expect(list.firstWhere((p) => p.def.id == 'streak_7').current, 7);
      expect(list.firstWhere((p) => p.def.id == 'streak_30').current, 30);
    });
  });

  group('self_awareness一致数', () {
    test('selfDifficulty == aiDifficultyValue の一致数を数える', () {
      final now = DateTime(2026, 9, 10);
      final reflections = [
        _r(date: now, self: 5, ai: QuestRank.S), // match
        _r(date: now.subtract(const Duration(days: 1)), self: 3, ai: QuestRank.A), // match
        _r(date: now.subtract(const Duration(days: 2)), self: 1, ai: QuestRank.B), // match
        _r(date: now.subtract(const Duration(days: 3)), self: 5, ai: QuestRank.B), // no
      ];
      final list = ReflectionBadgeCollection.build(
        player: _player(),
        reflections: reflections,
      );
      expect(list.firstWhere((p) => p.def.id == 'self_awareness').current, 3);
    });
  });

  group('ReflectionBadgeProgress getters', () {
    ReflectionBadgeProgress make(int current, int required) {
      return ReflectionBadgeProgress(
        def: kAllReflectionBadges.first,
        current: current,
        required: required,
        isUnlocked: false,
      );
    }

    test('ratio は 0.0〜1.0 にクランプ', () {
      expect(make(150, 100).ratio, 1.0);
      expect(make(50, 100).ratio, 0.5);
      expect(make(0, 100).ratio, 0.0);
    });

    test('required <= 0 の ratio は 0.0', () {
      expect(make(10, 0).ratio, 0.0);
    });

    test('percent は 0-100 int', () {
      expect(make(50, 100).percent, 50);
      expect(make(150, 100).percent, 100);
      expect(make(33, 100).percent, 33);
    });

    test('isComplete / remaining', () {
      expect(make(5, 5).isComplete, isTrue);
      expect(make(6, 5).isComplete, isTrue);
      expect(make(4, 5).isComplete, isFalse);
      expect(make(4, 5).remaining, 1);
      expect(make(9, 5).remaining, 0);
      expect(make(4, 0).isComplete, isFalse);
    });

    test('progressLabel は "current / required" 形式', () {
      expect(make(3, 5).progressLabel, '3 / 5');
    });

    test('負の値は ArgumentError', () {
      expect(
        () => ReflectionBadgeProgress(
          def: kAllReflectionBadges.first,
          current: -1,
          required: 5,
          isUnlocked: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReflectionBadgeProgress(
          def: kAllReflectionBadges.first,
          current: 0,
          required: -1,
          isUnlocked: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ソート・集計', () {
    test('tier昇順 → required昇順 → id昇順でソート', () {
      final list = ReflectionBadgeCollection.build(player: _player());
      for (int i = 1; i < list.length; i++) {
        final prev = list[i - 1];
        final cur = list[i];
        final tierCmp = prev.def.tier.compareTo(cur.def.tier);
        if (tierCmp != 0) {
          expect(tierCmp, lessThan(0));
        } else {
          final reqCmp = prev.required.compareTo(cur.required);
          if (reqCmp != 0) {
            expect(reqCmp, lessThan(0));
          } else {
            expect(prev.def.id.compareTo(cur.def.id), lessThan(0));
          }
        }
      }
    });

    test('earnedCount / groupByTier / summaryLabel', () {
      final list = ReflectionBadgeCollection.build(
        player: _player(badges: ['first_reflection', 'reflection_novice']),
      );
      expect(ReflectionBadgeCollection.earnedCount(list), 2);
      final grouped = ReflectionBadgeCollection.groupByTier(list);
      expect(grouped.keys.toList(), [1, 2, 3, 4]);
      expect(grouped[1]!.length, 3);
      expect(grouped[2]!.length, 4);
      expect(grouped[3]!.length, 3);
      expect(grouped[4]!.length, 2);
      expect(ReflectionBadgeCollection.summaryLabel(list), '獲得 2 / 12');
    });
  });

  group('tierラベル', () {
    test('1-4と未知tierのラベル', () {
      expect(reflectionBadgeTierLabel(1), 'ブロンズ');
      expect(reflectionBadgeTierLabel(2), 'シルバー');
      expect(reflectionBadgeTierLabel(3), 'ゴールド');
      expect(reflectionBadgeTierLabel(4), '伝説');
      expect(reflectionBadgeTierLabel(99), 'その他');
    });
  });
}
