import 'dart:convert';

import 'package:rpg_todo/features/shared/domain/pomodoro_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ポモドーロ実行状態の保存先。
abstract class PomodoroStateStore {
  /// 保存済み状態を読む（無ければ null）。
  Future<PomodoroSnapshot?> load();

  /// 状態を保存する。
  Future<void> save(PomodoroSnapshot snapshot);

  /// 保存済み状態を消す。
  Future<void> clear();
}

/// shared_preferences に保存する実装。
///
/// 保存・読込の失敗は全て握りつぶす（計時はメモリ側で継続できるため、
/// 永続化の失敗でアプリを落とさない）。
class SharedPreferencesPomodoroStateStore implements PomodoroStateStore {
  SharedPreferencesPomodoroStateStore({SharedPreferences? prefs})
      : _prefs = prefs;

  /// 保存キー（旧版との互換は持たない）。
  static const String storageKey = 'pomodoro_running_state_v1';

  final SharedPreferences? _prefs;

  Future<SharedPreferences> _resolve() async =>
      _prefs ?? await SharedPreferences.getInstance();

  @override
  Future<PomodoroSnapshot?> load() async {
    try {
      final prefs = await _resolve();
      return PomodoroSnapshot.tryFromJson(prefs.getString(storageKey));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(PomodoroSnapshot snapshot) async {
    try {
      final prefs = await _resolve();
      await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // 保存失敗は無視する（アプリを落とさない）。
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _resolve();
      await prefs.remove(storageKey);
    } catch (_) {
      // 消去失敗も無視する。
    }
  }
}

/// 試練用のメモリ実装。
class InMemoryPomodoroStateStore implements PomodoroStateStore {
  InMemoryPomodoroStateStore([this._snapshot]);

  PomodoroSnapshot? _snapshot;

  @override
  Future<PomodoroSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(PomodoroSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}
