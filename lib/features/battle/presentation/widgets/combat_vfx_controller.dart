import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';

/// Combat visual effects state machine.
///
/// Coordinates animation controllers for the full combat sequence:
///   idle → facing → attacking → victory | defeat
///
/// Battle phases per roadmap v2.1 ①:
/// - idle:    Pre-combat, enemy bobbing animation
/// - facing:  Player and enemy appear, dramatic pause
/// - attacking: Slash + hit sparks + damage numbers
/// - victory: Particle burst → Lottie celebration
/// - defeat:  Enemy fades, player retreats
///
/// Uses [BattleState] from domain/models for phase tracking.

/// Central controller for all combat VFX animations.
///
/// Manages a [SingleTickerProviderStateMixin] and exposes
/// sub-animators for each phase of the combat sequence.
///
/// Usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with SingleTickerProviderStateMixin {
///   late final CombatVfxController _vfx;
///
///   @override
///   void initState() {
///     super.initState();
///     _vfx = CombatVfxController(vsync: this);
///   }
///
///   void _onAttack() => _vfx.playAttackSequence(onComplete: () {
///     // transition to next state
///   });
///
///   @override
///   void dispose() {
///     _vfx.dispose();
///     super.dispose();
///   }
/// }
/// ```
class CombatVfxController {
  final TickerProvider vsync;

  CombatVfxController({required this.vsync}) {
    _init();
  }

  late final AnimationController _phaseController;
  late final AnimationController _slashController;
  late final AnimationController _sparkController;
  late final AnimationController _damageController;

  BattleState _currentPhase = BattleState.idle;
  BattleState get currentPhase => _currentPhase;

  // Public accessors for widget building
  AnimationController get phaseController => _phaseController;
  AnimationController get slashController => _slashController;
  AnimationController get sparkController => _sparkController;
  AnimationController get damageController => _damageController;

  // Duration constants
  static const _slashDuration = Duration(milliseconds: 400);
  static const _sparkDuration = Duration(milliseconds: 500);
  static const _damageDuration = Duration(milliseconds: 900);

  void _init() {
    _phaseController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 600),
    );
    _slashController = AnimationController(
      vsync: vsync,
      duration: _slashDuration,
    );
    _sparkController = AnimationController(
      vsync: vsync,
      duration: _sparkDuration,
    );
    _damageController = AnimationController(
      vsync: vsync,
      duration: _damageDuration,
    );
  }

  /// Play the idle/facing phase (enemy appears, dramatic pause).
  Future<void> playFaceOff() async {
    _currentPhase = BattleState.facing;
    await _phaseController.forward(from: 0);
    _currentPhase = BattleState.idle;
  }

  /// Play the full attack sequence: slash → sparks → damage numbers.
  Future<void> playAttackSequence({
    VoidCallback? onSlashPeak,
    VoidCallback? onComplete,
  }) async {
    _currentPhase = BattleState.attacking;

    // Phase 1: Slash sweep
    _slashController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 150));
    onSlashPeak?.call();

    // Phase 2: Hit sparks (concurrent with slash end)
    _sparkController.forward(from: 0);

    // Phase 3: Damage number float
    _damageController.forward(from: 0);

    await _slashController.forward().then((_) {
      _slashController.reset();
    });
    await _sparkController.forward().then((_) {
      _sparkController.reset();
    });
    await _damageController.forward().then((_) {
      _damageController.reset();
    });

    _currentPhase = BattleState.idle;
    onComplete?.call();
  }

  /// Transition to victory phase.
  void enterVictory() {
    _currentPhase = BattleState.victory;
  }

  /// Transition to defeat phase.
  void enterDefeat() {
    _currentPhase = BattleState.defeat;
    _phaseController.reverse();
  }

  /// Reset to idle.
  void resetToIdle() {
    _currentPhase = BattleState.idle;
    _phaseController.reset();
    _slashController.reset();
    _sparkController.reset();
    _damageController.reset();
  }

  void dispose() {
    _phaseController.dispose();
    _slashController.dispose();
    _sparkController.dispose();
    _damageController.dispose();
  }
}
