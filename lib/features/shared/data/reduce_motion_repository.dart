import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';

/// 「動きを減らす」設定の永続化境界。
abstract class ReduceMotionRepository {
  /// 保存値を読み出す。未保存・破損・未知値は null（= system 扱い）。
  Future<ReduceMotionSetting?> load();

  /// 設定を保存する。
  Future<void> save(ReduceMotionSetting setting);
}

/// Hive の専用 box（`reduce_motion_box`）に保存する実装。
///
/// 既存の `settingsBox` とは分離し、キーは [storageKey] の1つのみ。
/// Hive 未初期化・I/O 例外時は握りつぶして null（= system）を返し、
/// アプリ起動を妨げない。
class HiveReduceMotionRepository implements ReduceMotionRepository {
  const HiveReduceMotionRepository();

  static const String boxName = 'reduce_motion_box';
  static const String storageKey = 'setting';

  @override
  Future<ReduceMotionSetting?> load() async {
    try {
      final box = await Hive.openBox(boxName);
      final raw = box.get(storageKey);
      if (raw is! String) return null;
      for (final setting in ReduceMotionSetting.values) {
        if (setting.storageKey == raw) return setting;
      }
      return null;
    } catch (e) {
      debugPrint('[ReduceMotion] 読込失敗（system 扱い）: $e');
      return null;
    }
  }

  @override
  Future<void> save(ReduceMotionSetting setting) async {
    try {
      final box = await Hive.openBox(boxName);
      await box.put(storageKey, setting.storageKey);
    } catch (e) {
      debugPrint('[ReduceMotion] 保存失敗: $e');
    }
  }
}

/// 試練・プレビュー用のインメモリ実装。
class InMemoryReduceMotionRepository implements ReduceMotionRepository {
  InMemoryReduceMotionRepository([ReduceMotionSetting? initial])
      : _saved = initial;

  ReduceMotionSetting? _saved;
  int saveCount = 0;

  /// 最後に保存された値（未保存は null）。
  ReduceMotionSetting? get saved => _saved;

  @override
  Future<ReduceMotionSetting?> load() async => _saved;

  @override
  Future<void> save(ReduceMotionSetting setting) async {
    _saved = setting;
    saveCount++;
  }
}
