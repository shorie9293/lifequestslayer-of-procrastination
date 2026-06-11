import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/particle_effect.dart';

/// Victory celebration using Lottie animation with particle burst fallback.
///
/// Attempts to load [lottieAssetPath] via the Lottie package.
/// On load failure (missing asset, network error), falls back to
/// a programmatic [ParticleBurst] with a victory message.
///
/// Usage:
/// ```dart
/// VictoryAnimation(
///   lottieAssetPath: 'assets/animations/victory_burst.json',
///   onComplete: () => Navigator.pop(context),
/// )
/// ```
class VictoryAnimation extends StatefulWidget {
  /// Path to the Lottie JSON asset. Defaults to the bundled burst animation.
  final String lottieAssetPath;

  /// Called when the animation finishes (or fallback completes).
  final VoidCallback? onComplete;

  /// Text shown during the fallback particle burst.
  final String fallbackText;

  /// Total animation duration (for fallback timing).
  final Duration duration;

  const VictoryAnimation({
    super.key,
    this.lottieAssetPath = 'assets/animations/victory_burst.json',
    this.onComplete,
    this.fallbackText = 'クエスト完了\n💥',
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<VictoryAnimation> createState() => _VictoryAnimationState();
}

class _VictoryAnimationState extends State<VictoryAnimation>
    with SingleTickerProviderStateMixin {
  bool _lottieFailed = false;
  bool _completed = false;

  void _onLottieError(Object error) {
    if (_completed) return;
    setState(() => _lottieFailed = true);
  }

  void _onComplete() {
    if (_completed) return;
    _completed = true;
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_lottieFailed) {
      // Fallback: particle burst
      return ParticleBurst(
        text: widget.fallbackText,
        duration: widget.duration,
        onComplete: _onComplete,
      );
    }

    return Center(
      child: Lottie.asset(
        widget.lottieAssetPath,
        width: 280,
        height: 280,
        fit: BoxFit.contain,
        repeat: false,
        onLoaded: (composition) {
          // Lottie loaded successfully — schedule completion callback
          Future.delayed(composition.duration, _onComplete);
        },
        errorBuilder: (context, error, stackTrace) {
          // Trigger fallback on next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onLottieError(error);
          });
          // Show a placeholder while we transition
          return const SizedBox(width: 280, height: 280);
        },
      ),
    );
  }
}

/// Compact Lottie victory widget for inline use (e.g., inside dialogs).
///
/// Smaller version meant to be embedded in [BattleReportDialog].
class VictoryLottieInline extends StatelessWidget {
  final String lottieAssetPath;
  final VoidCallback? onLoaded;

  const VictoryLottieInline({
    super.key,
    this.lottieAssetPath = 'assets/animations/victory_burst.json',
    this.onLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      lottieAssetPath,
      width: 160,
      height: 160,
      fit: BoxFit.contain,
      repeat: false,
      onLoaded: (composition) => onLoaded?.call(),
      errorBuilder: (context, error, stackTrace) {
        // Silent fallback — show a simple star icon
        return const Icon(
          Icons.auto_awesome,
          size: 64,
          color: Colors.amberAccent,
        );
      },
    );
  }
}
