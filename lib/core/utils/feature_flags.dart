import 'package:rpg_todo/core/utils/feature_flag_service.dart';

/// 未完成機能を安全に混在させるための Feature Flag 定義（コンパイル時デフォルト）。
///
/// 既定値はコンパイル時定数で決定し、実行時のトグルは [FeatureFlagService] が
/// Hive へ永続化したオーバーライドで上書きする。
/// これにより A/Bテスト（ユーザー群で有効/無効を分岐）や、
/// 未完成機能の段階的ロールアウトを安全に実現できる。
enum FeatureFlag {
  /// 実験的バトルv2（討伐演出強化・未完成）。既定では無効。
  experimentalBattleV2(
    key: 'experimental_battle_v2',
    defaultEnabled: false,
    description: '討伐演出v2（戦術選択UI・アニメーション）。未完成機能のため既定無効。',
  ),

  /// スキルツリー・アビリティ体系（未完成）。既定では無効。
  skillTree(
    key: 'skill_tree',
    defaultEnabled: false,
    description: 'スキルツリー・アビリティ体系。A/B試験対象の未完成機能。',
  ),

  /// 振り返りの杜（内省システム・未完成）。既定では無効。
  reflectionGrove(
    key: 'reflection_grove',
    defaultEnabled: false,
    description: '振り返りの杜（内省システム）。未完成機能のため既定無効。',
  ),

  /// 既存の戦闘シーン表示をフラグでラップする実例（本番デフォルト ON）。
  /// 不具合発生時に デバッグ/運用 で OFF へ切替え可能な安全弁。
  battleSceneV2(
    key: 'battle_scene_v2',
    defaultEnabled: true,
    description: '戦闘シーンv2表示。安定機能をフラグでラップする実例（既定有効）。',
  );

  const FeatureFlag({
    required this.key,
    required this.defaultEnabled,
    required this.description,
  });

  /// Hive box 内での保存キー（一意）。
  final String key;

  /// コンパイル時デフォルト値（実行時オーバーライドが無い場合の値）。
  final bool defaultEnabled;

  /// 人間可読な説明（デバッグUI・A/B試験管理画面で表示する想定）。
  final String description;
}

/// フラグ定義への便宜アクセサ（`FeatureFlags.experimentalBattleV2` など）。
///
/// [FeatureFlag] enum を直接使うのが本命だが、呼び出し側の可読性のため
/// よく使うフラグを静的定数として公開する。
abstract final class FeatureFlags {
  static const experimentalBattleV2 = FeatureFlag.experimentalBattleV2;
  static const skillTree = FeatureFlag.skillTree;
  static const reflectionGrove = FeatureFlag.reflectionGrove;
  static const battleSceneV2 = FeatureFlag.battleSceneV2;
}
