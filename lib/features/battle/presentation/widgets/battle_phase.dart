import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/enemy_sprite.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/combat_animations.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/combat_vfx_controller.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/particle_effect.dart';

/// The combat phase orchestration widget — per roadmap v2.1 ①.
///
/// Manages the full RPG combat visual sequence:
///   idle → facing → attacking → victory | defeat
///
/// Coordinates [EnemySprite], [SlashEffect], [HitSparkEffect],
/// [DamageNumber], [ImpactBurst], and victory [ParticleBurst].
///
/// Usage:
/// ```dart
/// BattlePhaseWidget(
///   task: task,
///   playerAvatarPath: 'assets/images/skin_icon_1.png',
///   onComplete: (result) { /* victory or defeat */ },
/// )
/// ```
class BattlePhaseWidget extends StatefulWidget {
  /// The quest being fought.
  final Task task;

  /// Optional player avatar image path.
  final String? playerAvatarPath;

  /// Called after victory or defeat animation completes.
  /// [result] is 'victory' or 'defeat'.
  final ValueChanged<String> onComplete;

  /// Whether to auto-play the attack sequence on mount.
  final bool autoPlay;

  const BattlePhaseWidget({
    super.key,
    required this.task,
    this.playerAvatarPath,
    required this.onComplete,
    this.autoPlay = true,
  });

  @override
  State<BattlePhaseWidget> createState() => _BattlePhaseWidgetState();
}

class _BattlePhaseWidgetState extends State<BattlePhaseWidget>
    with SingleTickerProviderStateMixin {
  late final CombatVfxController _vfx;

  @override
  void initState() {
    super.initState();
    _vfx = CombatVfxController(vsync: this);

    if (widget.autoPlay) {
      _startSequence();
    }
  }

  Future<void> _startSequence() async {
    // Phase: Face-off (enemy appears)
    await _vfx.playFaceOff();
    await Future.delayed(const Duration(milliseconds: 300));

    // Phase: Attack sequence
    await _vfx.playAttackSequence(
      onSlashPeak: () {
        // Show hit impact at enemy position
        setState(() {});
      },
    );

    // Determine outcome based on task completion state
    final allSubTasksDone = widget.task.subTasks.every((s) => s.isCompleted);
    if (allSubTasksDone || widget.task.subTasks.isEmpty) {
      // Victory!
      _vfx.enterVictory();
      widget.onComplete('victory');
    } else {
      // Defeat — sub-tasks incomplete
      _vfx.enterDefeat();
      await Future.delayed(const Duration(milliseconds: 600));
      widget.onComplete('defeat');
    }
  }

  /// Public method to trigger attack on demand.
  Future<void> triggerAttack() async {
    await _vfx.playAttackSequence();
  }

  @override
  void dispose() {
    _vfx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A0A2E),
            Color(0xFF0D0D0D),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background particles / atmosphere
          if (_vfx.currentPhase == BattleState.victory)
            const _VictoryBackground(),

          // Main combat layout
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enemy area
              Expanded(
                flex: 2,
                child: Center(
                  child: _buildEnemyArea(),
                ),
              ),

              // Battle action zone
              Expanded(
                flex: 1,
                child: _buildActionZone(),
              ),

              // Player area
              Expanded(
                flex: 2,
                child: Center(
                  child: _buildPlayerArea(),
                ),
              ),
            ],
          ),

          // VFX overlay (slash, sparks, damage numbers)
          if (_vfx.currentPhase == BattleState.attacking)
            _buildVfxOverlay(),

          // Victory celebration
          if (_vfx.currentPhase == BattleState.victory)
            const _VictoryCelebration(),
        ],
      ),
    );
  }

  Widget _buildEnemyArea() {
    return EnemySprite(
      rank: widget.task.rank,
      imagePath: widget.task.enemyAssetPath,
      isAttacking: _vfx.currentPhase == BattleState.attacking,
      isDefeated: _vfx.currentPhase == BattleState.defeat,
    );
  }

  Widget _buildPlayerArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Player avatar placeholder
        Container(
          width: 80,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.blueGrey.withAlpha(60),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blueAccent.withAlpha(100),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.person,
            size: 48,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '冒険者',
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionZone() {
    // Placeholder for combat selection UI (handled by sibling task t_d6b1ce21)
    return const SizedBox.shrink();
  }

  Widget _buildVfxOverlay() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Slash effect across the screen
          Positioned.fill(
            child: SlashEffect(
              animation: _vfx.slashController,
            ),
          ),

          // Hit sparks at enemy position
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            child: Center(
              child: HitSparkEffect(
                animation: _vfx.sparkController,
                count: 16,
              ),
            ),
          ),

          // Damage number floating up
          Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Center(
              child: DamageNumber(
                value: 42,
                isCritical: widget.task.rank == QuestRank.S,
                isXp: false,
                controller: _vfx.damageController,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle animated background during victory phase.
class _VictoryBackground extends StatefulWidget {
  const _VictoryBackground();

  @override
  State<_VictoryBackground> createState() => _VictoryBackgroundState();
}

class _VictoryBackgroundState extends State<_VictoryBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _VictoryBgPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _VictoryBgPainter extends CustomPainter {
  final double progress;

  _VictoryBgPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amberAccent.withAlpha(15);
    final center = Offset(size.width / 2, size.height / 3);

    // Expanding rings
    for (int i = 0; i < 3; i++) {
      final r = 40.0 + ((progress + i * 0.33) % 1.0) * size.width * 0.6;
      paint.color = Colors.amberAccent.withAlpha((10 * (1.0 - (r / size.width))).round());
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_VictoryBgPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Full-screen victory celebration overlay.
class _VictoryCelebration extends StatelessWidget {
  const _VictoryCelebration();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Center(
        child: ParticleBurst(
          text: 'クエスト完了\n💥',
          duration: Duration(milliseconds: 1200),
        ),
      ),
    );
  }
}
