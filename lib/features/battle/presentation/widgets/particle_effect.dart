import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// パーティクル1粒のパラメータ
class _Particle {
  final double angle; // 放射角度 (rad)
  final double distance; // 中心からの飛距離
  final double size; // 直径
  final Color color; // 色
  final double delay; // 発射遅延 (0.0～0.15, アニメーション進捗の割合)

  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.delay,
  });
}

/// 討伐完了時のパーティクルバースト演出
///
/// 中心テキストを囲むように金色・琥珀色の粒子が放射状に飛び散り、
/// フェードアウトする。アニメーション完了時に [onComplete] が呼ばれる。
///
/// 使用例:
/// ```dart
/// ParticleBurst(
///   onComplete: () => Navigator.pop(context),
/// )
/// ```
class ParticleBurst extends StatefulWidget {
  /// 中心に表示するテキスト
  final String text;

  /// アニメーションの総時間
  final Duration duration;

  /// アニメーション完了時に呼ばれるコールバック
  final VoidCallback? onComplete;

  /// テキストのスタイル（null ならデフォルト）
  final TextStyle? textStyle;

  const ParticleBurst({
    super.key,
    this.text = 'クエスト完了\n💥',
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
    this.textStyle,
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 20個のパーティクルをランダム生成
    final random = Random();
    _particles = List.generate(20, (_) {
      return _Particle(
        angle: random.nextDouble() * 2 * pi,
        distance: 50 + random.nextDouble() * 100, // 50～150px
        size: 4 + random.nextDouble() * 6, // 4～10px
        color: random.nextBool() ? Colors.amber : Colors.orangeAccent,
        delay: random.nextDouble() * 0.15,
      );
    });

    // アニメーション開始 → 完了時にコールバック
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
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
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 中心テキスト（AnimatedBuilder の child としてキャッシュ）
            child!,
            // パーティクル群
            ..._particles.map(_buildParticle),
          ],
        );
      },
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: widget.textStyle ??
            GoogleFonts.vt323(
              fontSize: 80,
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// 1粒のパーティクルを生成
  Widget _buildParticle(_Particle p) {
    // 遅延を考慮した進捗 (0.0～1.0)
    final rawProgress =
        ((_controller.value - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
    // easeOut で加速→減速
    final curvedProgress = Curves.easeOut.transform(rawProgress);
    // 位置（中心からのオフセット）
    final dx = cos(p.angle) * p.distance * curvedProgress;
    final dy = sin(p.angle) * p.distance * curvedProgress;

    return Positioned(
      left: dx,
      top: dy,
      child: Opacity(
        opacity: (1.0 - rawProgress).clamp(0.0, 1.0),
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            color: p.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: p.color.withAlpha(180),
                blurRadius: p.size * 1.5,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
