import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/streak_freeze_state.dart';

/// お休み券の状態永続化インターフェース。
///
/// プレイヤー本体（Hive `players` box）とは **独立した box/key** に保存する。
/// 旧データには本キー自体が存在しないため、未保存時は
/// [StreakFreezeState.defaults]（残数0）へフォールバックする。
abstract class StreakFreezeRepository {
  Future<StreakFreezeState> load();
  Future<void> save(StreakFreezeState state);
}

/// Hive 実装。box `streak_freeze_box` / key `state` に JSON 文字列で保存。
class HiveStreakFreezeRepository implements StreakFreezeRepository {
  static const String boxName = 'streak_freeze_box';
  static const String keyName = 'state';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  @override
  Future<StreakFreezeState> load() async {
    final box = await _getBox();
    final raw = box.get(keyName);
    if (raw is! String) return StreakFreezeState.defaults;
    try {
      return StreakFreezeState.fromJson(jsonDecode(raw));
    } catch (_) {
      return StreakFreezeState.defaults;
    }
  }

  @override
  Future<void> save(StreakFreezeState state) async {
    final box = await _getBox();
    await box.put(keyName, jsonEncode(state.toJson()));
  }
}

/// 試練・注入用のメモリ内リポジトリ。
class InMemoryStreakFreezeRepository implements StreakFreezeRepository {
  InMemoryStreakFreezeRepository([StreakFreezeState? initial])
      : _state = initial ?? StreakFreezeState.defaults;

  StreakFreezeState _state;

  /// 保存された内容（試練からの実測用）。
  StreakFreezeState get state => _state;

  /// save が呼ばれた回数（「保存まで到達したか」を撃つため）。
  int saveCount = 0;

  @override
  Future<StreakFreezeState> load() async => _state;

  @override
  Future<void> save(StreakFreezeState state) async {
    _state = state;
    saveCount++;
  }
}
