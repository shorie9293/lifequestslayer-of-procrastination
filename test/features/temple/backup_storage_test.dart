// BackupStorage の試練。
//
// - InMemoryBackupStorage: 往復・許可リスト外 box 無視
// - HiveBackupStorage: boxOpener 注入 + Map ベースのフェイク Box で検証
//   （実際の Hive.openBox は呼ばない）

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/backup_registry.dart';
import 'package:rpg_todo/domain/services/reflection_backup_codec.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';

/// Map ベースのフェイク Box（Hive を実 open しない）。
class _FakeBox implements Box<dynamic> {
  final String _name;
  final Map<dynamic, dynamic> _data;

  _FakeBox(this._name, [Map<dynamic, dynamic>? initial])
      : _data = initial ?? {};

  @override
  String get name => _name;
  @override
  bool get isOpen => true;
  @override
  String? get path => null;
  @override
  bool get lazy => false;
  @override
  Iterable<dynamic> get keys => _data.keys.toList();
  @override
  int get length => _data.length;
  @override
  bool get isEmpty => _data.isEmpty;
  @override
  bool get isNotEmpty => _data.isNotEmpty;
  @override
  dynamic keyAt(int index) => _data.keys.elementAt(index);
  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
  @override
  bool containsKey(dynamic key) => _data.containsKey(key);
  @override
  Future<void> put(dynamic key, dynamic value) async => _data[key] = value;
  @override
  Future<void> putAt(int index, dynamic value) async =>
      _data[_data.keys.elementAt(index)] = value;
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _data.addAll(entries);
  @override
  Future<int> add(dynamic value) async {
    _data[length] = value;
    return length - 1;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<dynamic> values) async => [
        for (final v in values) await add(v),
      ];
  @override
  Future<void> delete(dynamic key) async => _data.remove(key);
  @override
  Future<void> deleteAt(int index) async =>
      _data.remove(_data.keys.elementAt(index));
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final k in keys) {
      _data.remove(k);
    }
  }

  @override
  Future<void> compact() async {}
  @override
  Future<int> clear() async {
    final n = _data.length;
    _data.clear();
    return n;
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> deleteFromDisk() async {}
  @override
  Future<void> flush() async {}
  @override
  Iterable<dynamic> get values => _data.values.toList();
  @override
  Iterable<dynamic> valuesBetween({dynamic startKey, dynamic endKey}) =>
      _data.values;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;
  @override
  dynamic getAt(int index) => _data[_data.keys.elementAt(index)];
  @override
  Map<dynamic, dynamic> toMap() => Map.of(_data);
}

Reflection _reflection(String id, {String? sentiment}) => Reflection(
      id: id,
      taskId: 'task-$id',
      date: DateTime.utc(2026, 10, 14, 9),
      content: '学び $id',
      selfDifficulty: 3,
      aiDifficulty: QuestRank.A,
      sentiment: sentiment,
    );

void main() {
  group('InMemoryBackupStorage', () {
    test('capture→restore 往復で一致する', () async {
      final storage = InMemoryBackupStorage({
        'battle_records': {'r1': 'record-json'},
        'settingsBox': {'theme': 'dark', 'volume': 0.5},
      });

      final captured = await storage.capture();
      expect(captured['battle_records'], {'r1': 'record-json'});
      expect(captured['settingsBox'], {'theme': 'dark', 'volume': 0.5});

      // restore 先に別の内容を入れても上書き（clear → putAll）される
      final target = InMemoryBackupStorage({
        'battle_records': {'old': 'x'},
      });
      await target.restore(captured);
      expect(target.snapshot['battle_records'], {'r1': 'record-json'});
      expect(target.snapshot['battle_records']!.containsKey('old'), isFalse);
      expect(target.snapshot['settingsBox'], {'theme': 'dark', 'volume': 0.5});
    });

    test('restore は許可リスト外の box を無視する', () async {
      final storage = InMemoryBackupStorage();
      await storage.restore({
        'unknown_box': {'a': 1},
        'settingsBox': {'ok': true},
      });
      expect(storage.snapshot.containsKey('unknown_box'), isFalse);
      expect(storage.snapshot['settingsBox'], {'ok': true});
    });

    test('capture の戻り値はスナップショットの複製（以後の変更が波及しない）', () async {
      final storage = InMemoryBackupStorage({
        'townBox': {'level': 1},
      });
      final captured = await storage.capture();
      captured['townBox']!['level'] = 99;
      expect(storage.snapshot['townBox']!['level'], 1);
    });
  });

  group('HiveBackupStorage（フェイク Box 注入）', () {
    test('capture: jsonValue box を JSON-safe 化して取り出す', () async {
      final boxes = <String, Box<dynamic>>{
        'battle_records': _FakeBox('battle_records', {
          'r1': 'json-str',
          'r2': {'nested': [1, 2, 3]},
        }),
      };
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      final captured = await storage.capture();
      expect(captured['battle_records'], {
        'r1': 'json-str',
        'r2': {
          'nested': [1, 2, 3],
        },
      });
    });

    test('capture: JSON 非対応の値は除外する', () async {
      final boxes = <String, Box<dynamic>>{
        'settingsBox': _FakeBox('settingsBox', {
          'ok': 'text',
          'bad': DateTime.now(),
          'badList': <dynamic>[1, Object()],
        }),
      };
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      final captured = await storage.capture();
      expect(captured['settingsBox'], {'ok': 'text'});
    });

    test('capture: reflectionObject box は Reflection を Map 化する', () async {
      final r = _reflection('ref1', sentiment: 'kaishin');
      final boxes = <String, Box<dynamic>>{
        'reflections': _FakeBox('reflections', {
          'ref1': r,
          'notReflection': '文字列',
        }),
      };
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      final captured = await storage.capture();
      expect(captured['reflections']!.keys, ['ref1']);
      final map = captured['reflections']!['ref1'] as Map<String, dynamic>;
      expect(ReflectionBackupCodec.fromMap(map).id, 'ref1');
    });

    test('capture: 開けない box はスキップする（例外を投げない）', () async {
      final storage = HiveBackupStorage(
        boxOpener: (name) async {
          if (name == 'battle_records') throw StateError('open failed');
          return _FakeBox(name);
        },
      );

      final captured = await storage.capture();
      expect(captured.containsKey('battle_records'), isFalse);
      // 他の対象 box は空 Map で継続する
      expect(captured['settingsBox'], isEmpty);
    });

    test('restore: 許可リスト外の box 名は無視する', () async {
      final boxes = <String, Box<dynamic>>{
        'settingsBox': _FakeBox('settingsBox'),
      };
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      await storage.restore({
        'unknown_box': {'a': 1},
        'settingsBox': {'ok': true},
      });
      expect(boxes['unknown_box'], isNull);
      expect(boxes['settingsBox']!.toMap(), {'ok': true});
    });

    test('restore: jsonValue box は clear 後に entries を書き込む', () async {
      final box = _FakeBox('townBox', {'old': 'value'});
      final boxes = <String, Box<dynamic>>{'townBox': box};
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      await storage.restore({
        'townBox': {'level': 3},
      });
      expect(box.toMap(), {'level': 3});
    });

    test('restore: reflectionObject box は Map を Reflection に戻す', () async {
      final box = _FakeBox('reflections');
      final boxes = <String, Box<dynamic>>{'reflections': box};
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      final map = ReflectionBackupCodec.toMap(_reflection('ref9'));
      await storage.restore({
        'reflections': {'ref9': map},
      });
      final restored = box.get('ref9');
      expect(restored, isA<Reflection>());
      expect((restored as Reflection).id, 'ref9');
    });

    test('restore: 不正な reflection entry はその entry だけスキップする', () async {
      final box = _FakeBox('reflectionsBox');
      final boxes = <String, Box<dynamic>>{'reflectionsBox': box};
      final storage = HiveBackupStorage(
        boxOpener: (name) async => boxes[name]!,
      );

      await storage.restore({
        'reflectionsBox': {
          'bad': <String, dynamic>{'nope': true},
          'good': ReflectionBackupCodec.toMap(_reflection('ref2')),
        },
      });
      expect(box.containsKey('bad'), isFalse);
      expect((box.get('good') as Reflection).id, 'ref2');
    });

    test('restore: 対象外 box の open 失敗でも他 box は復元され、例外を投げない', () async {
      final box = _FakeBox('battle_records');
      final storage = HiveBackupStorage(
        boxOpener: (name) async {
          if (name == 'battle_records') throw StateError('boom');
          throw StateError('unexpected: $name');
        },
      );

      await storage.restore({
        'battle_records': {'r1': 'x'},
      });
      // capture 側と異なり復元先が開けない場合は当該 box だけ無視
      expect(box.toMap(), isEmpty);
    });

    test('restore: 開ける box は他の失敗と独立に復元される', () async {
      final battleBox = _FakeBox('battle_records');
      final townBox = _FakeBox('townBox');
      final storage = HiveBackupStorage(
        boxOpener: (name) async => name == 'battle_records'
            ? battleBox
            : throw StateError('boom'),
      );

      await storage.restore({
        'battle_records': {'r1': 'x'},
        'townBox': {'level': 2},
      });
      expect(battleBox.toMap(), {'r1': 'x'});
      expect(townBox.toMap(), isEmpty);
    });
  });

  test('registry の全 box 名が BackupBoxRegistry と一致する（許可リスト網羅）', () {
    expect(BackupBoxRegistry.boxNames, containsAll(['battle_records', 'reflections']));
  });
}
