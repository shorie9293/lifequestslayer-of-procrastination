import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';

/// 討伐戦績リポジトリ（改善提案 #56）の試練。
///
/// 実 Hive の openBox は試練内で呼ばない（zone 汚染防止）。
/// Hive 実装にはテスト用フェイク Box を注入して検証する。
class _FakeBox implements Box<String> {
  final Map<String, String> store = {};

  @override
  Iterable<String> get values => store.values;

  @override
  Iterable<dynamic> get keys => store.keys;

  @override
  int get length => store.length;

  @override
  Future<void> put(dynamic key, String value) async => store[key] = value;

  @override
  Future<int> clear() async {
    final n = store.length;
    store.clear();
    return n;
  }

  @override
  String? get(dynamic key, {String? defaultValue}) => store[key];

  @override
  bool get isOpen => true;

  @override
  Future<void> delete(dynamic key) async {
    store.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final base = DateTime(2026, 9, 15, 12);

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

  group('InMemoryBattleRecordRepository', () {
    test('追加・読込ができる', () async {
      final repo = InMemoryBattleRecordRepository();
      final r = rec('r1', base, true);
      await repo.add(r);
      final loaded = await repo.load();
      expect(loaded, [r]);
    });

    test('同一IDの重複を防ぐ', () async {
      final repo = InMemoryBattleRecordRepository();
      await repo.add(rec('r1', base, true));
      await repo.add(rec('r1', base, false));
      final loaded = await repo.load();
      expect(loaded.length, 1);
      expect(loaded.first.isVictory, isFalse);
    });

    test('clear で全消去', () async {
      final repo = InMemoryBattleRecordRepository();
      await repo.add(rec('r1', base, true));
      await repo.clear();
      expect(await repo.load(), isEmpty);
    });

    test('500件上限で最古を削除する', () async {
      final repo = InMemoryBattleRecordRepository();
      for (var i = 0; i < 505; i++) {
        await repo.add(rec('r$i', base.add(Duration(minutes: i)), true));
      }
      final loaded = await repo.load();
      expect(loaded.length, 500);
      expect(loaded.any((r) => r.id == 'r0'), isFalse);
      expect(loaded.any((r) => r.id == 'r4'), isFalse);
      expect(loaded.any((r) => r.id == 'r5'), isTrue);
      expect(loaded.any((r) => r.id == 'r504'), isTrue);
    });
  });

  group('HiveBattleRecordRepository（注入 Box）', () {
    test('JSON 往復・破損スキップ・重複防止・500件上限', () async {
      final box = _FakeBox();
      final repo = HiveBattleRecordRepository(box: box);

      await repo.add(rec('r1', base, true, combo: 3, remaining: 2));
      await repo.add(rec('r2', base.add(const Duration(minutes: 1)), false));
      // 破損エントリを直接混入
      box.store['broken'] = '{not json';

      final loaded = await repo.load();
      expect(loaded.length, 2);
      expect(loaded.firstWhere((r) => r.id == 'r1').comboCount, 3);

      // 同一IDは上書き（重複防止）
      await repo.add(rec('r1', base, false));
      final loaded2 = await repo.load();
      expect(loaded2.length, 2);
      expect(
        loaded2.firstWhere((r) => r.id == 'r1').isVictory,
        isFalse,
      );

      // 500件上限: 最古を削除
      for (var i = 10; i < 520; i++) {
        await repo.add(rec('r$i', base.add(Duration(minutes: i + 10)), true));
      }
      final loaded3 = await repo.load();
      // 破損エントリ 'broken' も1スロット消費するため、
      // 有効レコードは 500 - 1 = 499 件（'broken' は読み飛ばし対象）。
      expect(loaded3.length, 499);
      expect(loaded3.any((r) => r.id == 'r1'), isFalse);

      await repo.clear();
      expect(await repo.load(), isEmpty);
    });

    test('保存値は JSON 文字列である', () async {
      final box = _FakeBox();
      final repo = HiveBattleRecordRepository(box: box);
      await repo.add(rec('r9', base, true));
      final raw = box.store['r9']!;
      expect(jsonDecode(raw), isA<Map<String, dynamic>>());
      final back = BattleRecord.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      expect(back.id, 'r9');
    });
  });

  group('BattleRecordRepository 抽象クラス', () {
    test('Hive 実装は抽象クラスを実装する', () {
      final repo = HiveBattleRecordRepository(box: _FakeBox());
      expect(repo, isA<BattleRecordRepository>());
      final mem = InMemoryBattleRecordRepository();
      expect(mem, isA<BattleRecordRepository>());
    });

    test('Noop実装は Hive に触れず空を返す（未配線環境の保護）', () async {
      // ⚠️ Hive 未初期化で openBox を呼ぶと、失敗が共有 Completer にも流れて
      // zone の未処理エラーになる（呼出側の try/catch では抑止できない）。
      // そのため未配線環境では NoopBattleRecordRepository を既定にする。
      final repo = NoopBattleRecordRepository();
      expect(repo, isA<BattleRecordRepository>());
      expect(await repo.load(), isEmpty);
      await expectLater(repo.add(rec('r1', base, true)), completes);
      await expectLater(repo.clear(), completes);
      expect(await repo.load(), isEmpty);
    });
  });
}
