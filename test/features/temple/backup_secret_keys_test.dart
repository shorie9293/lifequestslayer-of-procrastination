// バックアップからの秘密キー除外の試練。
//
// - isSecretKey: 純粋判定（大小無視・接頭辞一致・通常キーは false）
// - capture: settingsBox の appLock.* を控えに載せない（通常設定は載る）
// - restore: 控えに秘密キーが混じっていても書き戻さず、既存値を保持する

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/services/backup_secret_keys.dart';
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

void main() {
  group('isSecretKey', () {
    test('アプリロックの実在キーは秘密と判定する', () {
      expect(isSecretKey('appLock.passcodeHash'), isTrue);
      expect(isSecretKey('appLock.enabled'), isTrue);
      expect(isSecretKey('appLock.method'), isTrue);
      expect(isSecretKey('appLock.relockGraceSeconds'), isTrue);
      expect(isSecretKey('appLock.failedAttempts'), isTrue);
      expect(isSecretKey('appLock.lockedUntil'), isTrue);
    });

    test('大文字小文字を無視する', () {
      expect(isSecretKey('APPLOCK.PASSCODEHASH'), isTrue);
      expect(isSecretKey('AppLock.PasscodeHash'), isTrue);
      expect(isSecretKey('PassCode'), isTrue);
    });

    test('接頭辞一致のみを秘密とし、途中出現は対象外', () {
      expect(isSecretKey('my_appLock.passcodeHash'), isFalse);
      expect(isSecretKey('passcode'), isTrue);
      expect(isSecretKey('passcodeHash'), isTrue);
    });

    test('通常の設定キーは秘密ではない', () {
      expect(isSecretKey('fontSizeScale'), isFalse);
      expect(isSecretKey('themeMode'), isFalse);
      expect(isSecretKey('lastBackupTime'), isFalse);
      expect(isSecretKey('town_events_count.2026-11-09'), isFalse);
      expect(isSecretKey('knowledgeQuestEnabled'), isFalse);
    });
  });

  group('HiveBackupStorage: capture の秘密除外', () {
    test('settingsBox の appLock.* は控え JSON に現れない', () async {
      final settings = _FakeBox('settingsBox', {
        'appLock.passcodeHash': r'v2$deadbeef',
        'appLock.enabled': true,
        'appLock.method': 'passcode',
        'appLock.failedAttempts': 3,
        'fontSizeScale': 1.2,
      });
      final storage = HiveBackupStorage(
        boxOpener: (name) async =>
            name == 'settingsBox' ? settings : _FakeBox(name),
      );

      final captured = await storage.capture();
      final box = captured['settingsBox']!;

      expect(box.keys.any((k) => k.toLowerCase().startsWith('applock.')),
          isFalse);
      expect(box.containsKey('appLock.passcodeHash'), isFalse);
      expect(box.containsKey('appLock.enabled'), isFalse);
      expect(box.containsKey('appLock.method'), isFalse);
      expect(box.containsKey('appLock.failedAttempts'), isFalse);
      // 控え全体を文字列化してもハッシュが漏れない
      expect(captured.toString().contains('deadbeef'), isFalse);
    });

    test('capture は通常設定を巻き添えにしない', () async {
      final settings = _FakeBox('settingsBox', {
        'appLock.passcodeHash': r'v2$deadbeef',
        'fontSizeScale': 1.2,
        'themeMode': 'dark',
        'town_events_count.2026-11-09': '2',
      });
      final storage = HiveBackupStorage(
        boxOpener: (name) async =>
            name == 'settingsBox' ? settings : _FakeBox(name),
      );

      final captured = await storage.capture();
      expect(captured['settingsBox'], {
        'fontSizeScale': 1.2,
        'themeMode': 'dark',
        'town_events_count.2026-11-09': '2',
      });
    });
  });

  group('HiveBackupStorage: restore の秘密素通し防止', () {
    test('控えの秘密キーは書き戻さず、既存値を保持する', () async {
      final settings = _FakeBox('settingsBox', {
        'appLock.passcodeHash': r'v2$localonly',
        'appLock.enabled': true,
        'fontSizeScale': 1.0,
      });
      final boxes = <String, Box<dynamic>>{};
      final storage = HiveBackupStorage(
        boxOpener: (name) async =>
            boxes.putIfAbsent(name, () => name == 'settingsBox'
                ? settings
                : _FakeBox(name)),
      );

      await storage.restore({
        'settingsBox': {
          'appLock.passcodeHash': r'v2$fromotherdevice',
          'appLock.enabled': false,
          'fontSizeScale': 1.5,
        },
      });

      expect(settings.get('appLock.passcodeHash'), r'v2$localonly');
      expect(settings.get('appLock.enabled'), isTrue);
      // 通常キーは従来通り復元される
      expect(settings.get('fontSizeScale'), 1.5);
      expect(settings.length, 3);
    });

    test('秘密キー入り控えでも、秘密が存在しなかった端末には書かれない', () async {
      final settings = _FakeBox('settingsBox', {'fontSizeScale': 1.0});
      final boxes = <String, Box<dynamic>>{};
      final storage = HiveBackupStorage(
        boxOpener: (name) async =>
            boxes.putIfAbsent(name, () => name == 'settingsBox'
                ? settings
                : _FakeBox(name)),
      );

      await storage.restore({
        'settingsBox': {
          'appLock.passcodeHash': r'v2$fromotherdevice',
          'fontSizeScale': 1.5,
        },
      });

      expect(settings.containsKey('appLock.passcodeHash'), isFalse);
      expect(settings.get('fontSizeScale'), 1.5);
    });
  });
}
