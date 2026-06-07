import 'package:rpg_todo/domain/models/battle_state.dart';

/// 戦闘フェーズ状態機械。
///
/// 戦闘の状態遷移を管理し、無効な遷移を拒否する。
/// 外部からは [transitionTo] で状態を変更し、
/// [currentState] で現在の状態を取得する。
///
/// 状態遷移図:
/// ```
/// idle ──→ facing ──→ attacking ──→ victory
///   ↑        │                        │
///   │        └──────→ idle ←──────────┘
///   │                                  │
///   └────────── defeat ←───────────────┘
/// ```
class BattlePhase {
  BattleState _state = BattleState.idle;

  /// 現在の戦闘状態。
  BattleState get currentState => _state;

  /// 戦闘中かどうか。
  bool get isInCombat => _state.isInCombat;

  /// 戦闘が終了したかどうか。
  bool get isFinished => _state.isFinished;

  /// 指定した状態への遷移が有効かどうか。
  bool canTransitionTo(BattleState target) => _state.canTransitionTo(target);

  /// 状態を遷移する。無効な遷移の場合は [BattlePhaseException] を投げる。
  ///
  /// 戻り値: 遷移前の状態。
  BattleState transitionTo(BattleState target) {
    if (!_state.canTransitionTo(target)) {
      throw BattlePhaseException(
        '無効な状態遷移: $_state → $target',
        from: _state,
        to: target,
      );
    }
    final previous = _state;
    _state = target;
    return previous;
  }

  /// 戦闘を開始する（idle → facing）。
  /// すでに戦闘中の場合は [BattlePhaseException] を投げる。
  void startBattle() {
    if (_state != BattleState.idle) {
      throw BattlePhaseException(
        '戦闘はすでに進行中です（現在の状態: $_state）',
        from: _state,
        to: BattleState.facing,
      );
    }
    _state = BattleState.facing;
  }

  /// 戦術を選択する（facing → attacking）。
  void selectTactic() {
    if (_state != BattleState.facing) {
      throw BattlePhaseException(
        '戦術選択は対峙中のみ可能です（現在の状態: $_state）',
        from: _state,
        to: BattleState.attacking,
      );
    }
    _state = BattleState.attacking;
  }

  /// 討伐成功を宣言する（attacking → victory）。
  void declareVictory() {
    if (_state != BattleState.attacking) {
      throw BattlePhaseException(
        '勝利宣言は攻撃中のみ可能です（現在の状態: $_state）',
        from: _state,
        to: BattleState.victory,
      );
    }
    _state = BattleState.victory;
  }

  /// 討伐失敗／撤退を宣言する（attacking → defeat）。
  void declareDefeat() {
    if (_state != BattleState.attacking) {
      throw BattlePhaseException(
        '敗北宣言は攻撃中のみ可能です（現在の状態: $_state）',
        from: _state,
        to: BattleState.defeat,
      );
    }
    _state = BattleState.defeat;
  }

  /// 戦闘終了後、アイドル状態に戻す。
  /// victory または defeat からのみ遷移可能。
  void returnToIdle() {
    if (!_state.isFinished) {
      throw BattlePhaseException(
        '戦闘終了後のみアイドルに戻れます（現在の状態: $_state）',
        from: _state,
        to: BattleState.idle,
      );
    }
    _state = BattleState.idle;
  }

  /// 強制的にアイドルに戻す（デバッグ／リセット用）。
  /// どの状態からでも遷移可能。
  void forceReset() {
    _state = BattleState.idle;
  }

  /// 対峙中にキャンセルしてアイドルに戻る（facing → idle）。
  void cancelBattle() {
    if (_state != BattleState.facing) {
      throw BattlePhaseException(
        '戦闘キャンセルは対峙中のみ可能です（現在の状態: $_state）',
        from: _state,
        to: BattleState.idle,
      );
    }
    _state = BattleState.idle;
  }
}

/// 戦闘フェーズの状態遷移に関する例外。
class BattlePhaseException implements Exception {
  final String message;
  final BattleState from;
  final BattleState to;

  const BattlePhaseException(this.message, {required this.from, required this.to});

  @override
  String toString() => 'BattlePhaseException: $message';
}
