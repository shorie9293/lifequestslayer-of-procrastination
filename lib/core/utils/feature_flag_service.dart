import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import 'feature_flags.dart';

/// Feature Flag の実行時トグルを Hive 永続化するサービス。
///
/// 既定値はコンパイル時定数（[FeatureFlag.defaultEnabled]）で決まり、
/// 実行時のオーバーライドは Hive の `featureFlagsBox` へ保存される。
/// A/Bテスト基盤として、同一フラグをユーザー群で分岐して有効化できる。
///
/// 使い方:
/// ```dart
/// final featureFlags = getIt<FeatureFlagService>();
/// if (await featureFlags.isEnabled(FeatureFlags.experimentalBattleV2)) {
///   // 新バトルUI
/// } else {
///   // 旧バトルUI
/// }
/// ```
@lazySingleton
class FeatureFlagService {
  FeatureFlagService({Box? box}) : _injectedBox = box;

  static const String _boxName = 'featureFlagsBox';

  /// テストなどで注入した Hive ボックス（null なら [Hive.openBox] を使用）。
  final Box? _injectedBox;

  /// 現在の値をキャッシュ（同期読み出し [isEnabledSync] 用）。
  final Map<FeatureFlag, bool> _cache = {};

  Future<Box> _openBox() async {
    final injected = _injectedBox;
    if (injected != null && injected.isOpen) return injected;
    return Hive.openBox(_boxName);
  }

  /// フラグが有効かどうかを判定する。
  ///
  /// 実行時オーバーライドが存在すればそれを、無ければコンパイル時デフォルトを返す。
  /// Hive が未初期化・読込失敗の場合は安全にデフォルトへフォールバックする。
  Future<bool> isEnabled(FeatureFlag flag) async {
    try {
      final box = await _openBox();
      final value =
          box.get(flag.key, defaultValue: flag.defaultEnabled) as bool;
      _cache[flag] = value;
      return value;
    } catch (_) {
      return flag.defaultEnabled;
    }
  }

  /// 実行時にフラグの有効/無効を設定（Hive へ永続化）。
  Future<void> setEnabled(FeatureFlag flag, bool enabled) async {
    final box = await _openBox();
    await box.put(flag.key, enabled);
    _cache[flag] = enabled;
  }

  /// 実行時オーバーライドを破棄し、コンパイル時デフォルトへ戻す。
  Future<void> reset(FeatureFlag flag) async {
    try {
      final box = await _openBox();
      await box.delete(flag.key);
      _cache.remove(flag);
    } catch (_) {}
  }

  /// 全フラグのオーバーライドを破棄（デバッグ・テスト用）。
  Future<void> resetAll() async {
    try {
      final box = await _openBox();
      for (final flag in FeatureFlag.values) {
        await box.delete(flag.key);
        _cache.remove(flag);
      }
    } catch (_) {}
  }

  /// 非同期を介さず現在の値を返す（同期ショートカット）。
  ///
  /// 未読込のフラグはコンパイル時デフォルトを返す。
  bool isEnabledSync(FeatureFlag flag) => _cache[flag] ?? flag.defaultEnabled;
}
