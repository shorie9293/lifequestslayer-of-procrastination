import 'package:rpg_todo/features/battle/domain/battle_tactic.dart';

/// 戦術1つ分の報酬補正（純粋な値オブジェクト）。
class BattleTacticEffect {
  /// 補正対象の戦術。null は「戦術未選択＝補正なし」を表す。
  final BattleTactic? tactic;

  /// EXP倍率。
  final double expMultiplier;

  /// コイン倍率。
  final double coinMultiplier;

  /// 戦果報告書へ載せる説明（未選択時は空文字）。
  final String message;

  const BattleTacticEffect({
    required this.tactic,
    required this.expMultiplier,
    required this.coinMultiplier,
    required this.message,
  });
}

/// 戦術 → 報酬補正の表引き（純粋・副作用なし）。
///
/// 設計方針: 補正値を画面の if 文へ散らさず、対応表をこの1箇所に閉じる。
/// 呼出側（TaskCompletionService）は [expFor] / [coinsFor] を通すだけでよい。
class BattleOutcomeCalculator {
  const BattleOutcomeCalculator._();

  /// 戦術未選択時の補正（後方互換のため完全に無補正）。
  static const BattleTacticEffect neutral = BattleTacticEffect(
    tactic: null,
    expMultiplier: 1.0,
    coinMultiplier: 1.0,
    message: '',
  );

  static const Map<BattleTactic, BattleTacticEffect> _table = {
    BattleTactic.attack: BattleTacticEffect(
      tactic: BattleTactic.attack,
      expMultiplier: 1.0,
      coinMultiplier: 1.0,
      message: '⚔️ 攻撃の型：標準の報酬',
    ),
    BattleTactic.defend: BattleTacticEffect(
      tactic: BattleTactic.defend,
      expMultiplier: 0.7,
      coinMultiplier: 1.5,
      message: '🛡️ 防御の型：EXP×0.7／コイン×1.5',
    ),
    BattleTactic.skill: BattleTacticEffect(
      tactic: BattleTactic.skill,
      expMultiplier: 1.3,
      coinMultiplier: 0.8,
      message: '✨ スキルの型：EXP×1.3／コイン×0.8',
    ),
  };

  /// [tactic] に対応する補正を返す。未選択（null）は [neutral]。
  static BattleTacticEffect effectFor(BattleTactic? tactic) {
    if (tactic == null) return neutral;
    return _table[tactic] ?? neutral;
  }

  /// 基礎EXPに戦術補正を適用する（四捨五入・負値は0にクランプ）。
  static int expFor(int baseExp, BattleTactic? tactic) =>
      _apply(baseExp, effectFor(tactic).expMultiplier);

  /// 基礎コインに戦術補正を適用する（四捨五入・負値は0にクランプ）。
  static int coinsFor(int baseCoins, BattleTactic? tactic) =>
      _apply(baseCoins, effectFor(tactic).coinMultiplier);

  static int _apply(int base, double multiplier) {
    if (base <= 0) return 0;
    final value = (base * multiplier).round();
    return value < 0 ? 0 : value;
  }
}
