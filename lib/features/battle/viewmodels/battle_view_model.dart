import 'package:flutter/foundation.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_phase.dart';
import 'package:rpg_todo/features/battle/domain/combo_system.dart';

/// 戦術の選択肢。
///
/// v2.1 戦術選択UI: 「⚔️攻撃」「🛡️防御」「✨スキル」の3択。
enum BattleTactic {
  /// 通常攻撃 — 標準的な討伐。
  attack,

  /// 防御 — サブクエスト未完了でも経験値半減で撤退可能。
  defend,

  /// スキル — ジョブスキルに応じた特殊効果（v2.1スキルツリー連動）。
  skill,
}

/// 戦闘結果の要約。
///
/// [resolveCombat] の戻り値として使われる。
class BattleResult {
  /// 討伐に成功したか。
  final bool isVictory;

  /// 討伐対象のクエスト。
  final Task task;

  /// 獲得EXP。
  final int expGained;

  /// 獲得コイン。
  final int coinsGained;

  /// コンボボーナスEXP（コンボ倍率による上乗せ分）。
  final int comboBonusExp;

  /// 現在のコンボ数（討伐後）。
  final int comboCount;

  /// コンボ倍率（討伐後）。
  final double comboMultiplier;

  /// ボーナスメッセージ一覧。
  final List<String> bonusMessages;

  /// 撤退の場合のペナルティEXP（敗北時のみ）。
  final int? penaltyExp;

  const BattleResult({
    required this.isVictory,
    required this.task,
    required this.expGained,
    required this.coinsGained,
    required this.comboBonusExp,
    required this.comboCount,
    required this.comboMultiplier,
    this.bonusMessages = const [],
    this.penaltyExp,
  });
}

/// 戦闘画面の状態を管理するViewModel。
///
/// 戦闘フェーズ状態機械 ([BattlePhase]) とコンボシステム ([ComboSystem]) を
/// 束ね、UIにバインド可能な状態を提供する。
///
/// 使用例:
/// ```dart
/// final battleVM = BattleViewModel();
/// battleVM.enterBattle(task);    // idle → facing
/// battleVM.selectTactic(attack);  // facing → attacking
/// final result = battleVM.resolveCombat(/* ... */);
/// battleVM.dismissResult();       // → idle
/// ```
class BattleViewModel extends ChangeNotifier {
  final BattlePhase _phase = BattlePhase();
  final ComboSystem _combo;

  /// 現在戦闘中のクエスト（対峙中のみ非null）。
  Task? _currentTask;

  /// 選択中の戦術。
  BattleTactic? _selectedTactic;

  /// 最後の戦闘結果。
  BattleResult? _lastResult;

  BattleViewModel({
    ComboSystem? combo,
  }) : _combo = combo ?? ComboSystem();

  // ── 公開プロパティ ──

  /// 現在の戦闘状態。
  BattleState get currentState => _phase.currentState;

  /// 戦闘中かどうか。
  bool get isInCombat => _phase.isInCombat;

  /// 戦闘が終了したかどうか。
  bool get isFinished => _phase.isFinished;

  /// 現在戦闘中のクエスト。
  Task? get currentTask => _currentTask;

  /// 選択中の戦術。
  BattleTactic? get selectedTactic => _selectedTactic;

  /// 最後の戦闘結果。
  BattleResult? get lastResult => _lastResult;

  /// 現在のコンボ数。
  int get comboCount => _combo.comboCount;

  /// 現在のコンボ倍率。
  double get comboMultiplier => _combo.currentMultiplier;

  /// コンボが有効かどうか。
  bool get isComboActive => _combo.isComboActive;

  /// コンボの残り時間。
  Duration get remainingComboTime => _combo.remainingComboTime;

  /// コンボボーナスEXPを計算する。
  int calcComboBonusExp(int baseExp) => _combo.calcComboBonusExp(baseExp);

  // ── 戦闘フロー操作 ──

  /// 戦闘を開始する（idle → facing）。
  ///
  /// [task] に討伐対象のクエストを渡す。
  /// すでに戦闘中の場合は [BattlePhaseException] を投げる。
  void enterBattle(Task task) {
    _phase.startBattle();
    _currentTask = task;
    _selectedTactic = null;
    _lastResult = null;
    notifyListeners();
  }

  /// 戦術を選択する（facing → attacking）。
  ///
  /// [tactic] に選択した戦術を渡す。
  void selectTactic(BattleTactic tactic) {
    _phase.selectTactic();
    _selectedTactic = tactic;
    notifyListeners();
  }

  /// 討伐成功を宣言する（attacking → victory）。
  ///
  /// コンボシステムに勝利を通知し、コンボ数を増加させる。
  /// [expGained], [coinsGained], [bonusMessages] に討伐結果を渡す。
  ///
  /// 戻り値: 戦闘結果の要約。
  BattleResult declareVictory({
    required int expGained,
    required int coinsGained,
    List<String> bonusMessages = const [],
  }) {
    _phase.declareVictory();
    _combo.onVictory();
    final comboBonus = _combo.calcComboBonusExp(expGained);

    final result = BattleResult(
      isVictory: true,
      task: _currentTask!,
      expGained: expGained,
      coinsGained: coinsGained,
      comboBonusExp: comboBonus,
      comboCount: _combo.comboCount,
      comboMultiplier: _combo.currentMultiplier,
      bonusMessages: bonusMessages,
    );
    _lastResult = result;
    notifyListeners();
    return result;
  }

  /// 討伐失敗／撤退を宣言する（attacking → defeat）。
  ///
  /// コンボシステムに敗北を通知する（コンボ数は即座にリセットされない）。
  /// [penaltyExp] にペナルティEXP（半減後の値など）を渡す。
  BattleResult declareDefeat({
    int penaltyExp = 0,
    List<String> bonusMessages = const [],
  }) {
    _phase.declareDefeat();
    _combo.onDefeat();

    final result = BattleResult(
      isVictory: false,
      task: _currentTask!,
      expGained: 0,
      coinsGained: 0,
      comboBonusExp: 0,
      comboCount: _combo.comboCount,
      comboMultiplier: _combo.currentMultiplier,
      bonusMessages: bonusMessages,
      penaltyExp: penaltyExp,
    );
    _lastResult = result;
    notifyListeners();
    return result;
  }

  /// 戦闘結果表示を閉じてアイドルに戻る（victory/defeat → idle）。
  void dismissResult() {
    _phase.returnToIdle();
    _currentTask = null;
    _selectedTactic = null;
    notifyListeners();
  }

  /// 対峙中に戦闘をキャンセルする（facing → idle）。
  void cancelBattle() {
    _phase.cancelBattle();
    _currentTask = null;
    _selectedTactic = null;
    notifyListeners();
  }

  /// 強制的に戦闘状態をリセットする（どの状態からでも）。
  void forceReset() {
    _phase.forceReset();
    _currentTask = null;
    _selectedTactic = null;
    _lastResult = null;
    notifyListeners();
  }

  /// コンボシステムを強制リセットする。
  void resetCombo() {
    _combo.reset();
    notifyListeners();
  }
}
