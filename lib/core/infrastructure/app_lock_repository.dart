import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

/// アプリロックの方式。
enum AppLockMethod { none, passcode, biometric }

/// アプリロック設定の永続化の抽象（コード適応神書 原則⑤ 依存性注入）。
abstract class AppLockRepository {
  bool isEnabled();

  Future<void> setEnabled(bool enabled);

  AppLockMethod getMethod();

  Future<void> setMethod(AppLockMethod method);

  String? getPasscodeHash();

  Future<void> setPasscode(String passcode);

  Future<void> clearPasscode();

  bool verifyPasscode(String passcode);
}

/// Hive `settingsBox` 実装。既存 SettingsRepository の様式に倣う。
class HiveAppLockRepository implements AppLockRepository {
  static const String _boxName = 'settingsBox';
  static const String _kEnabled = 'appLock.enabled';
  static const String _kMethod = 'appLock.method';
  static const String _kHash = 'appLock.passcodeHash';

  static const String _salt = 'rpg-app-lock:';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  @override
  bool isEnabled() {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
    return (box?.get(_kEnabled, defaultValue: false) as bool?) ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final box = await _openBox();
    await box.put(_kEnabled, enabled);
  }

  @override
  AppLockMethod getMethod() {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
    final name = box?.get(_kMethod) as String?;
    return AppLockMethod.values
        .firstWhere((m) => m.name == name, orElse: () => AppLockMethod.none);
  }

  @override
  Future<void> setMethod(AppLockMethod method) async {
    final box = await _openBox();
    await box.put(_kMethod, method.name);
  }

  @override
  String? getPasscodeHash() {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
    return box?.get(_kHash) as String?;
  }

  @override
  Future<void> setPasscode(String passcode) async {
    final box = await _openBox();
    await box.put(_kHash, _hashOf(passcode));
  }

  @override
  Future<void> clearPasscode() async {
    final box = await _openBox();
    await box.delete(_kHash);
  }

  @override
  bool verifyPasscode(String passcode) {
    final stored = getPasscodeHash();
    if (stored == null) return false;
    return _constantTimeEquals(stored, _hashOf(passcode));
  }

  String _hashOf(String passcode) =>
      sha256.convert(utf8.encode('$_salt$passcode')).toString();
}

/// 試練用のインメモリ実装。
class InMemoryAppLockRepository implements AppLockRepository {
  bool _enabled = false;
  AppLockMethod _method = AppLockMethod.none;
  String? _hash;
  static const String _salt = 'rpg-app-lock:';

  @override
  bool isEnabled() => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;

  @override
  AppLockMethod getMethod() => _method;

  @override
  Future<void> setMethod(AppLockMethod method) async => _method = method;

  @override
  String? getPasscodeHash() => _hash;

  @override
  Future<void> setPasscode(String passcode) async =>
      _hash = _hashOf(passcode);

  @override
  Future<void> clearPasscode() async => _hash = null;

  @override
  bool verifyPasscode(String passcode) {
    final stored = _hash;
    if (stored == null) return false;
    return _constantTimeEquals(stored, _hashOf(passcode));
  }

  String _hashOf(String passcode) =>
      sha256.convert(utf8.encode('$_salt$passcode')).toString();
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
