/// 戦闘フェーズの状態を表す列挙型。
///
/// v2.1「戦神降臨の章」: 修練場をRPG戦闘シーンに変えるための状態機械。
///
/// [idle]      - 非戦闘状態（修練場の一覧表示中）
/// [facing]    - 敵と対峙中（戦術選択UI表示中）
/// [attacking] - 戦術実行中（アニメーション再生中）
/// [victory]   - 討伐成功（戦果報告書表示中）
/// [defeat]    - 討伐失敗／撤退（サブタスク未完了など）
enum BattleState {
  idle,
  facing,
  attacking,
  victory,
  defeat;

  /// 有効な状態遷移を定義する。
  /// idle → facing, facing → attacking, attacking → victory/defeat,
  /// victory/defeat → idle.
  bool canTransitionTo(BattleState target) {
    switch (this) {
      case BattleState.idle:
        return target == BattleState.facing;
      case BattleState.facing:
        return target == BattleState.attacking || target == BattleState.idle;
      case BattleState.attacking:
        return target == BattleState.victory ||
            target == BattleState.defeat;
      case BattleState.victory:
      case BattleState.defeat:
        return target == BattleState.idle;
    }
  }

  /// 戦闘中かどうか（idle 以外はすべて戦闘中とみなす）。
  bool get isInCombat => this != BattleState.idle;

  /// 戦闘が終了したかどうか。
  bool get isFinished => this == BattleState.victory || this == BattleState.defeat;

  /// 勝利状態か。
  bool get isVictory => this == BattleState.victory;

  /// 敗北状態か。
  bool get isDefeat => this == BattleState.defeat;
}
