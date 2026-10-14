// 親探針: 全データバックアップの「合成の不変条件」を撃つ。
//
// 眷属は個別操作（capture単体・restore単体・encode/decode単体）しか撃たない。
// 本探針は実運用の一本道
//   capture → encode → JSON文字列 → decode → restore（別box集合）
// を通し、全 box 種が往復すること・後方互換 JSON が既存データを破壊しないこと・
// 許可リスト外 box が退避対象外であることを実測する。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/backup_registry.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';

/// do-nothing なフェイク Box（noSuchMethod で残りを吸収）。
class _ProbeBox implements Box<dynamic> {
  final String _name;
  final Map<dynamic, dynamic> _data;
  _ProbeBox(this._name, [Map<dynamic, dynamic>? initial])
      : _data = Map<dynamic, dynamic>.of(initial ?? {});

  @override
  String get name => _name;
  @override
  Iterable<dynamic> get keys => _data.keys.toList();
  @override
  int get length => _data.length;
  @override
  bool containsKey(dynamic key) => _data.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data.containsKey(key) ? _data[key] : defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => _data[key] = value;
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _data.addAll(entries);
  @override
  Future<int> clear() async {
    final n = _data.length;
    _data.clear();
    return n;
  }

  @override
  Map<dynamic, dynamic> toMap() => Map<dynamic, dynamic>.of(_data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Reflection _ref(String id, {String? sentiment}) => Reflection(
      id: id,
      taskId: 't-$id',
      date: DateTime.utc(2026, 10, 14, 9),
      content: '学び $id',
      selfDifficulty: 4,
      aiDifficulty: QuestRank.S,
      sentiment: sentiment,
    );

void main() {
  group('親探針: capture→encode→decode→restore の合成', () {
    test('全 box 種が JSON 往復し、別 box 集合へ復元される', () async {
      // 送り側の実データ（Box を模す）
      final source = <String, _ProbeBox>{
        'battle_records': _ProbeBox('battle_records', {'r1': '{"win":true}'}),
        'practice_logs': _ProbeBox('practice_logs', {'d1': '{"count":3}'}),
        'task_time_records': _ProbeBox('task_time_records', {'t1': '{"m":30}'}),
        'task_templates': _ProbeBox('task_templates', {'tp1': '{"title":"修行"}'}),
        'reminderBox': _ProbeBox('reminderBox', {'rm1': '{"at":"08:00"}'}),
        'gryphon_reports': _ProbeBox('gryphon_reports', {
          'g1': {'id': 'g1', 'summary': '今週の学び', 'score': 7},
        }),
        'settingsBox': _ProbeBox('settingsBox', {'theme': 'dark', 'volume': 0.5}),
        'notification_settings': _ProbeBox('notification_settings', {
          'enabled': true,
          'hour': 21,
        }),
        'crossAppSettings': _ProbeBox('crossAppSettings', {'linked': true}),
        'tutorialBox': _ProbeBox('tutorialBox', {'seen': true}),
        'townBox': _ProbeBox('townBox', {'level': 4, 'name': '我が町'}),
        'reflections': _ProbeBox('reflections', {
          'ref1': _ref('ref1', sentiment: 'kaishin'),
          'ref2': _ref('ref2'),
        }),
        'reflectionsBox': _ProbeBox('reflectionsBox', {'ref3': _ref('ref3')}),
        // 許可リスト外（退避対象外であることを確かめる）
        'playerBox': _ProbeBox('playerBox', {'p': 'hidden'}),
        'featureFlagsBox': _ProbeBox('featureFlagsBox', {'f': true}),
        'iapPendingBox': _ProbeBox('iapPendingBox', {'i': 1}),
      };

      final sender = HiveBackupStorage(boxOpener: (n) async => source[n]!);
      final captured = await sender.capture();

      // 許可リスト外は退避されない（データ保護）
      expect(captured.containsKey('playerBox'), isFalse);
      expect(captured.containsKey('featureFlagsBox'), isFalse);
      expect(captured.containsKey('iapPendingBox'), isFalse);
      // 許可リスト内は全件キーが存在する
      for (final spec in BackupBoxRegistry.specs) {
        expect(captured.containsKey(spec.boxName), isTrue,
            reason: '${spec.boxName} が capture に含まれない');
      }

      final player = Player(coins: 1234, gems: 56);
      final tasks = [
        Task(id: 'task-1', title: '魔物討伐', status: TaskStatus.active),
      ];
      final json = FullBackupService()
          .encode(player: player, tasks: tasks, boxes: captured);

      // JSON は文字列として外部ファイルへ出せること
      final raw = jsonDecode(json) as Map<String, dynamic>;
      expect(raw['version'], 2);
      expect((raw['boxes'] as Map).keys, contains('battle_records'));

      // 受け側: 空の別 box 集合へ復元
      final target = <String, _ProbeBox>{
        for (final spec in BackupBoxRegistry.specs)
          spec.boxName: _ProbeBox(spec.boxName),
      };
      final receiver = HiveBackupStorage(boxOpener: (n) async => target[n]!);

      final decoded = FullBackupService().decode(json);
      expect(decoded, isNotNull);
      expect(decoded!.player.coins, player.coins);
      expect(decoded.tasks.single.title, '魔物討伐');

      await receiver.restore(decoded.boxes);

      // 文字列系
      expect(target['battle_records']!.toMap(), {'r1': '{"win":true}'});
      expect(target['practice_logs']!.toMap(), {'d1': '{"count":3}'});
      expect(target['task_time_records']!.toMap(), {'t1': '{"m":30}'});
      expect(target['task_templates']!.toMap(), {'tp1': '{"title":"修行"}'});
      expect(target['reminderBox']!.toMap(), {'rm1': '{"at":"08:00"}'});
      // Map 系（ネストも保持）
      expect(target['gryphon_reports']!.toMap(), {
        'g1': {'id': 'g1', 'summary': '今週の学び', 'score': 7},
      });
      // プリミティブ系
      expect(target['settingsBox']!.toMap(), {'theme': 'dark', 'volume': 0.5});
      expect(target['notification_settings']!.toMap(), {
        'enabled': true,
        'hour': 21,
      });
      expect(target['crossAppSettings']!.toMap(), {'linked': true});
      expect(target['tutorialBox']!.toMap(), {'seen': true});
      expect(target['townBox']!.toMap(), {'level': 4, 'name': '我が町'});
      // オブジェクト系は Reflection に戻る
      final r1 = target['reflections']!.get('ref1');
      expect(r1, isA<Reflection>());
      expect((r1 as Reflection).id, 'ref1');
      expect(r1.sentiment, 'kaishin');
      expect(r1.aiDifficulty, QuestRank.S);
      expect(r1.date, DateTime.utc(2026, 10, 14, 9));
      expect((target['reflections']!.get('ref2') as Reflection).sentiment, isNull);
      expect((target['reflectionsBox']!.get('ref3') as Reflection).id, 'ref3');
      // 受け側の許可リスト外 box は触られない
      expect(target['playerBox'], isNull);
    });

    test('後方互換: version 1 の JSON 復元で既存データが破壊されない', () async {
      // 旧形式のバックアップ（boxes キーなし）
      final legacy = jsonEncode({
        'version': 1,
        'exportedAt': '2026-10-01T00:00:00.000',
        'player': Player(coins: 42).toJson(),
        'tasks': <dynamic>[],
      });

      final decoded = FullBackupService().decode(legacy);
      expect(decoded, isNotNull);
      expect(decoded!.boxes, isEmpty);

      // 端末には既に戦績が入っている状況
      final device = <String, _ProbeBox>{
        'battle_records': _ProbeBox('battle_records', {'r9': '{"win":false}'}),
      };
      final storage = HiveBackupStorage(boxOpener: (n) async => device[n]!);
      await storage.restore(decoded.boxes);

      // 旧形式に boxes が無い以上、既存の戦績を消してはならない
      expect(device['battle_records']!.toMap(), {'r9': '{"win":false}'});
    });
  });
}
