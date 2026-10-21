import 'package:flutter/foundation.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';

/// 「動きを減らす」設定の状態管理。
///
/// 初回は [ReduceMotionSetting.system]（端末設定に従う）。
/// [load] で永続化値を復元し、[setSetting] で状態更新と永続化を行う。
class ReduceMotionViewModel extends ChangeNotifier {
  ReduceMotionViewModel(this._repository);

  final ReduceMotionRepository _repository;

  ReduceMotionSetting setting = ReduceMotionSetting.system;

  /// 永続化値を読み出す。未保存（null）なら system のまま。
  Future<void> load() async {
    final stored = await _repository.load();
    if (stored == null) return;
    if (stored == setting) return;
    setting = stored;
    notifyListeners();
  }

  /// 設定を更新し、必ず永続化層へ保存する。
  Future<void> setSetting(ReduceMotionSetting v) async {
    final changed = v != setting;
    setting = v;
    if (changed) notifyListeners();
    await _repository.save(v);
  }
}
