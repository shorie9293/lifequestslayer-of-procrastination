import 'dart:convert';
import 'dart:math';

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

  /// 復帰時の再施錠までの猶予（秒）。既定 0（即時）。
  int getRelockGraceSeconds();

  Future<void> setRelockGraceSeconds(int seconds);

  /// 連続失敗回数。
  int getFailedAttempts();

  Future<void> setFailedAttempts(int attempts);

  /// ロックアウト解除時刻。null はロックアウトなし。
  DateTime? getLockedUntil();

  Future<void> setLockedUntil(DateTime? until);

  /// 失敗回数とロックアウトを初期化する。
  Future<void> resetAttempts();
}

/// ハッシュ方式の版。`v2:<iterations>:<saltHex>:<hashHex>`。
const int _kIterations = 1200;

/// 旧形式の固定 salt。互換照合のみに使う。
const String _kLegacySalt = 'rpg-app-lock:';

String _randomSaltHex() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// saltHex + ':' + passcode を起点に sha256 を [iterations] 回連鎖させる。
String _deriveV2(String saltHex, String passcode, int iterations) {
  var digest = sha256.convert(utf8.encode('$saltHex:$passcode'));
  for (var i = 1; i < iterations; i++) {
    digest = sha256.convert(digest.bytes);
  }
  return digest.toString();
}

/// v2 形式の保存値を作る（salt は毎回新規生成）。
String _v2HashOf(String passcode) {
  final saltHex = _randomSaltHex();
  final hashHex = _deriveV2(saltHex, passcode, _kIterations);
  return 'v2:$_kIterations:$saltHex:$hashHex';
}

/// 旧方式（固定 salt + 単発 sha256）。既存ユーザーの照合にのみ残す。
String _legacyHashOf(String passcode) =>
    sha256.convert(utf8.encode('$_kLegacySalt$passcode')).toString();

bool _isV2(String stored) => stored.startsWith('v2:');

/// 保存値 [stored] が [passcode] と一致するか（v2 / 旧形式の両対応）。
bool _matchesStored(String stored, String passcode) {
  if (_isV2(stored)) {
    final parts = stored.split(':');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final saltHex = parts[2];
    final expected = 'v2:$iterations:$saltHex:'
        '${_deriveV2(saltHex, passcode, iterations)}';
    return _constantTimeEquals(stored, expected);
  }
  return _constantTimeEquals(stored, _legacyHashOf(passcode));
}

/// Hive `settingsBox` 実装。既存 SettingsRepository の様式に倣う。
class HiveAppLockRepository implements AppLockRepository {
  static const String _boxName = 'settingsBox';
  static const String _kEnabled = 'appLock.enabled';
  static const String _kMethod = 'appLock.method';
  static const String _kHash = 'appLock.passcodeHash';
  static const String _kGrace = 'appLock.relockGraceSeconds';
  static const String _kFailed = 'appLock.failedAttempts';
  static const String _kLockedUntil = 'appLock.lockedUntil';

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Box? get _box => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;

  @override
  bool isEnabled() {
    return (_box?.get(_kEnabled, defaultValue: false) as bool?) ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final box = await _openBox();
    await box.put(_kEnabled, enabled);
  }

  @override
  AppLockMethod getMethod() {
    final name = _box?.get(_kMethod) as String?;
    return AppLockMethod.values
        .firstWhere((m) => m.name == name, orElse: () => AppLockMethod.none);
  }

  @override
  Future<void> setMethod(AppLockMethod method) async {
    final box = await _openBox();
    await box.put(_kMethod, method.name);
  }

  @override
  String? getPasscodeHash() => _box?.get(_kHash) as String?;

  @override
  Future<void> setPasscode(String passcode) async {
    final box = await _openBox();
    await box.put(_kHash, _v2HashOf(passcode));
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
    if (!_matchesStored(stored, passcode)) return false;
    if (!_isV2(stored)) {
      // 旧形式から無強制移行（照合できた時だけ v2 で保存し直す）。
      // ignore: discarded_futures
      setPasscode(passcode);
    }
    return true;
  }

  @override
  int getRelockGraceSeconds() =>
      (_box?.get(_kGrace, defaultValue: 0) as int?) ?? 0;

  @override
  Future<void> setRelockGraceSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', '0以上を指定せよ');
    }
    final box = await _openBox();
    await box.put(_kGrace, seconds);
  }

  @override
  int getFailedAttempts() =>
      (_box?.get(_kFailed, defaultValue: 0) as int?) ?? 0;

  @override
  Future<void> setFailedAttempts(int attempts) async {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts', '0以上を指定せよ');
    }
    final box = await _openBox();
    await box.put(_kFailed, attempts);
  }

  @override
  DateTime? getLockedUntil() {
    final millis = _box?.get(_kLockedUntil) as int?;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> setLockedUntil(DateTime? until) async {
    final box = await _openBox();
    if (until == null) {
      await box.delete(_kLockedUntil);
    } else {
      await box.put(_kLockedUntil, until.millisecondsSinceEpoch);
    }
  }

  @override
  Future<void> resetAttempts() async {
    final box = await _openBox();
    await box.put(_kFailed, 0);
    await box.delete(_kLockedUntil);
  }
}

/// 試練用のインメモリ実装。
class InMemoryAppLockRepository implements AppLockRepository {
  bool _enabled = false;
  AppLockMethod _method = AppLockMethod.none;
  String? _hash;
  int _grace = 0;
  int _failed = 0;
  DateTime? _lockedUntil;

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
  Future<void> setPasscode(String passcode) async => _hash = _v2HashOf(passcode);

  @override
  Future<void> clearPasscode() async => _hash = null;

  @override
  bool verifyPasscode(String passcode) {
    final stored = _hash;
    if (stored == null) return false;
    if (!_matchesStored(stored, passcode)) return false;
    if (!_isV2(stored)) {
      // 旧形式から無強制移行。
      // ignore: discarded_futures
      setPasscode(passcode);
    }
    return true;
  }

  /// 試練用: 任意の保存値（旧形式ハッシュ等）を直接仕込む。
  void debugSetPasscodeHash(String? stored) => _hash = stored;

  @override
  int getRelockGraceSeconds() => _grace;

  @override
  Future<void> setRelockGraceSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', '0以上を指定せよ');
    }
    _grace = seconds;
  }

  @override
  int getFailedAttempts() => _failed;

  @override
  Future<void> setFailedAttempts(int attempts) async {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts', '0以上を指定せよ');
    }
    _failed = attempts;
  }

  @override
  DateTime? getLockedUntil() => _lockedUntil;

  @override
  Future<void> setLockedUntil(DateTime? until) async => _lockedUntil = until;

  @override
  Future<void> resetAttempts() async {
    _failed = 0;
    _lockedUntil = null;
  }
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
