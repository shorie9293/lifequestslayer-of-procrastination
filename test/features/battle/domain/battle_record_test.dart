import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';

/// 討伐戦績モデル（改善提案 #56）の試練。
void main() {
  final base = DateTime(2026, 9, 15, 10, 30);

  group('BattleRecord コンストラクタ検証', () {
    test('正常値で生成できる', () {
      final r = BattleRecord(
        id: 'r1',
        title: 'スライム討伐',
        occurredAt: base,
        isVictory: true,
        comboCount: 3,
        remainingSubTasks: 2,
      );
      expect(r.id, 'r1');
      expect(r.isVictory, isTrue);
      expect(r.comboCount, 3);
      expect(r.remainingSubTasks, 2);
    });

    test('空の id は ArgumentError', () {
      expect(
        () => BattleRecord(
          id: '',
          title: 'x',
          occurredAt: base,
          isVictory: true,
          comboCount: 0,
          remainingSubTasks: 0,
        ),
        throwsArgumentError,
      );
    });

    test('空の title は ArgumentError', () {
      expect(
        () => BattleRecord(
          id: 'r1',
          title: '',
          occurredAt: base,
          isVictory: false,
          comboCount: 0,
          remainingSubTasks: 0,
        ),
        throwsArgumentError,
      );
    });

    test('負の comboCount は 0 に丸められる', () {
      final r = BattleRecord(
        id: 'r1',
        title: 'x',
        occurredAt: base,
        isVictory: true,
        comboCount: -5,
        remainingSubTasks: 0,
      );
      expect(r.comboCount, 0);
    });

    test('負の remainingSubTasks は 0 に丸められる', () {
      final r = BattleRecord(
        id: 'r1',
        title: 'x',
        occurredAt: base,
        isVictory: true,
        comboCount: 0,
        remainingSubTasks: -1,
      );
      expect(r.remainingSubTasks, 0);
    });
  });

  group('JSON 往復', () {
    test('toJson → fromJson で等価に復元する', () {
      final r = BattleRecord(
        id: 'r1',
        title: 'ゴーレム',
        occurredAt: base,
        isVictory: true,
        comboCount: 7,
        remainingSubTasks: 3,
      );
      final back = BattleRecord.fromJson(r.toJson());
      expect(back, equals(r));
      expect(back.hashCode, r.hashCode);
    });
  });

  group('fromJson 破損検出', () {
    test('欠落キーは FormatException', () {
      expect(
        () => BattleRecord.fromJson({
          'id': 'r1',
          'title': 'x',
          'occurredAt': base.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('型不一致は FormatException', () {
      expect(
        () => BattleRecord.fromJson({
          'id': 'r1',
          'title': 'x',
          'occurredAt': 'not-a-date',
          'isVictory': 'yes',
          'comboCount': 0,
          'remainingSubTasks': 0,
        }),
        throwsFormatException,
      );
    });

    test('不正な日時文字列は FormatException', () {
      expect(
        () => BattleRecord.fromJson({
          'id': 'r1',
          'title': 'x',
          'occurredAt': 'not-a-date',
          'isVictory': true,
          'comboCount': 0,
          'remainingSubTasks': 0,
        }),
        throwsFormatException,
      );
    });

    test('JSON 経由でも負値は 0 に丸められる', () {
      final back = BattleRecord.fromJson({
        'id': 'r1',
        'title': 'x',
        'occurredAt': base.toIso8601String(),
        'isVictory': false,
        'comboCount': -2,
        'remainingSubTasks': -9,
      });
      expect(back.comboCount, 0);
      expect(back.remainingSubTasks, 0);
    });
  });

  group('値等価', () {
    test('同一内容は等価・異なる内容は非等価', () {
      final a = BattleRecord(
        id: 'r1',
        title: 'x',
        occurredAt: base,
        isVictory: true,
        comboCount: 1,
        remainingSubTasks: 0,
      );
      final b = BattleRecord(
        id: 'r1',
        title: 'x',
        occurredAt: base,
        isVictory: true,
        comboCount: 1,
        remainingSubTasks: 0,
      );
      final c = BattleRecord(
        id: 'r2',
        title: 'x',
        occurredAt: base,
        isVictory: true,
        comboCount: 1,
        remainingSubTasks: 0,
      );
      expect(a, equals(b));
      expect(a == c, isFalse);
      expect(a == a, isTrue);
    });
  });
}
