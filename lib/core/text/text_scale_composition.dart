import 'package:flutter/widgets.dart';

/// 端末（OS）の文字サイズ設定と、アプリ内の文字サイズ設定を乗算で合成する
/// [TextScaler]。
///
/// `MediaQueryData.copyWith(textScaler: ...)` は **置換** ゆえ、アプリ内倍率を
/// そのまま渡すと端末のアクセシビリティ設定（Android の「特大」等）が捨てられる。
/// ここでは [MediaQuery.textScalerOf]（非線形スケーリングを含む端末設定）を基点に、
/// アプリ内倍率をフォントサイズへ乗算する。
class CompositeTextScaler implements TextScaler {
  const CompositeTextScaler(this.base, this.multiplier)
      : assert(multiplier >= 0);

  /// 端末設定の基準となるスケーラ。
  final TextScaler base;

  /// アプリ内の文字サイズ倍率。
  final double multiplier;

  @override
  double scale(double fontSize) => base.scale(fontSize * multiplier);

  @override
  double get textScaleFactor => scale(1);

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    assert(maxScaleFactor >= minScaleFactor);
    final clamped =
        multiplier.clamp(minScaleFactor, maxScaleFactor).toDouble();
    return clamped == multiplier ? this : CompositeTextScaler(base, clamped);
  }

  @override
  bool operator ==(Object other) =>
      other is CompositeTextScaler &&
      other.base == base &&
      other.multiplier == multiplier;

  @override
  int get hashCode => Object.hash(base, multiplier);

  @override
  String toString() => 'CompositeTextScaler($base, ${multiplier}x)';
}

/// [TextScaler] を純粋に合成する（context 不要・試練から直接撃てる）。
TextScaler composeTextScaler(TextScaler systemScaler, double appScale) =>
    CompositeTextScaler(systemScaler, appScale);

/// 端末設定（[MediaQuery.textScalerOf]）×アプリ内倍率を合成した [TextScaler]。
TextScaler composeWithSystemTextScaler(
  BuildContext context,
  double appScale,
) =>
    composeTextScaler(MediaQuery.textScalerOf(context), appScale);
