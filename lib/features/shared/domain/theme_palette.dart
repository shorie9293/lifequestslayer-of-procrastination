import 'package:flutter/material.dart';

/// 明度（Brightness）で解決する色トークン。
///
/// 画面側に直書きされていた色リテラルを、テーマ明度に応じた意味トークンへ集約する。
/// **ダーク時の値は従来の直書きリテラルと完全一致**させており、ダークの見た目は
/// 1px も変わらない。ライト時のみ、和紙白背景に対して 3.0:1（目標 4.5:1）以上を
/// 満たす濃色へ差し替える。
///
/// ```dart
/// final palette = GamePalette.of(context);
/// Text('本文', style: TextStyle(color: palette.onSurfaceMuted));
/// ```
@immutable
class GamePalette {
  /// ライトテーマか否か。
  final bool isLight;

  const GamePalette({required this.isLight});

  /// 現在の [BuildContext] のテーマ明度からパレットを解決する。
  factory GamePalette.of(BuildContext context) =>
      GamePalette(isLight: Theme.of(context).brightness == Brightness.light);

  // ── 前景（文字・アイコン） ─────────────────────────────

  /// 主要な本文色。ダーク: Colors.white / ライト: #2B2B2B
  Color get onSurface => isLight ? const Color(0xFF2B2B2B) : Colors.white;

  /// 副次的な本文色。ダーク: Colors.white70 / ライト: #4A4A4A
  Color get onSurfaceMuted =>
      isLight ? const Color(0xFF4A4A4A) : Colors.white70;

  /// 補助ラベル色。ダーク: Colors.white54 / ライト: #5A5A5A
  Color get onSurfaceFaint =>
      isLight ? const Color(0xFF5A5A5A) : Colors.white54;

  /// 最も弱い注記色。ダーク: Colors.white38 / ライト: #6B6B6B
  Color get onSurfaceFaintest =>
      isLight ? const Color(0xFF6B6B6B) : Colors.white38;

  /// 金のアクセント文字。ダーク: テーマ金 #D4A038 / ライト: #7A5200
  Color get accent =>
      isLight ? const Color(0xFF7A5200) : const Color(0xFFD4A038);

  /// 強調用の金文字（旧 #FFD700）。ダーク: #FFD700 / ライト: #6B4800
  Color get accentStrong =>
      isLight ? const Color(0xFF6B4800) : const Color(0xFFFFD700);

  /// 成功・見出しの緑（旧 #4CAF50）。ダーク: #4CAF50 / ライト: #1B5E20
  Color get success =>
      isLight ? const Color(0xFF1B5E20) : const Color(0xFF4CAF50);

  /// 注意・負の強調（旧 #E85050 系）。ダーク: #E57373 / ライト: #A31515
  Color get danger =>
      isLight ? const Color(0xFFA31515) : const Color(0xFFE57373);

  // ── 背景（カード・枠・トラック） ────────────────────────

  /// 通常カードの背景。ダーク: Colors.black26 / ライト: 白 80%
  Color get cardBackground =>
      isLight ? const Color(0xCCFFFFFF) : Colors.black26;

  /// 濃いカードの背景。ダーク: Colors.black38 / ライト: 白 90%
  Color get cardBackgroundStrong =>
      isLight ? const Color(0xE6FFFFFF) : Colors.black38;

  /// カード枠線。ダーク: Colors.white12 / ライト: 黒 20%
  Color get border => isLight ? const Color(0x33000000) : Colors.white12;

  /// バー・ゲージの溝。ダーク: Colors.white10 / ライト: 黒 8%
  Color get track => isLight ? const Color(0x14000000) : Colors.white10;

  /// グラフのグリッド線。ダーク: Colors.white12 / ライト: 黒 20%
  Color get grid => isLight ? const Color(0x33000000) : Colors.white12;

  /// 画面地に敷く画像オーバーレイ。ライトでは画像を敷かないため未使用。
  Color get scrim =>
      isLight ? Colors.transparent : Colors.black.withValues(alpha: 0.7);

  /// 画面地に背景画像を敷くか（ライトは和紙無地）。
  bool get usesBackdropImage => !isLight;

  // ── アクセント色の可読化 ───────────────────────────────

  /// ライト時のみ、与えられた色を [minRatio] を満たすまで暗くする。
  /// ダーク時は**そのまま返す**（見た目不変）。
  Color readable(Color color, {double minRatio = 4.5}) {
    if (!isLight) return color;
    if (_contrastRatio(color, _lightCardReference) >= minRatio) return color;
    var current = color;
    for (double t = 0.05; t <= 0.95; t += 0.05) {
      current = Color.lerp(color, const Color(0xFF1A1A1A), t)!;
      if (_contrastRatio(current, _lightCardReference) >= minRatio) {
        return current;
      }
    }
    return current;
  }

  static const _lightCardReference = Color(0xFFF4F1E6);

  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
