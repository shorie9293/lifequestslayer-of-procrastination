import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/player.dart';

/// ジョブ別のテーマ定義（GameViewModelから分離）
/// 和風化改修: 全ジョブ共通で深紫(#1A1040)基調の背景、金(#D4A038)アクセント
class GameThemes {
  GameThemes._();

  // ── 和風パレット ──
  static const _gold = Color(0xFFD4A038);
  static const _deepPurple = Color(0xFF1A1040);
  static const _washiDark = Color(0xFF2A2520);
  static const _inkBlack = Color(0xFF0D0D1A);

  static final _base = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _gold,
    scaffoldBackgroundColor: _inkBlack,
    useMaterial3: true,
  );

  /// 浪人 — 和紙黒基調、金アクセント
  static final adventurer = _base.copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: _deepPurple, elevation: 0),
    colorScheme: const ColorScheme.dark(
        primary: _gold,
        secondary: _gold,
        surface: _washiDark,
        error: Color(0xFFE85050)),
  );

  /// 侍 — 墨黒基調、朱アクセント
  static final warrior = _base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF1A0D0D),
    appBarTheme:
        const AppBarTheme(backgroundColor: Color(0xFF2A1010), elevation: 0),
    colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE85050),
        secondary: _gold,
        surface: Color(0xFF2A1A1A)),
  );

  /// 法師 — 墨黒基調、青緑アクセント
  static final cleric = _base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF0D1A1A),
    appBarTheme:
        const AppBarTheme(backgroundColor: Color(0xFF102A2A), elevation: 0),
    colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4DB6AC),
        secondary: _gold,
        surface: Color(0xFF1A2A2A)),
  );

  /// 陰陽師 — 深紫基調、金アクセント
  static final wizard = _base.copyWith(
    scaffoldBackgroundColor: _deepPurple,
    appBarTheme:
        const AppBarTheme(backgroundColor: Color(0xFF261650), elevation: 0),
    colorScheme: const ColorScheme.dark(
        primary: _gold,
        secondary: Color(0xFFBB86FC),
        surface: Color(0xFF1A1040)),
  );

  static ThemeData forJob(Job job) {
    return switch (job) {
      Job.samurai => warrior,
      Job.monk => cleric,
      Job.mystic => wizard,
      Job.adventurer => adventurer,
    };
  }

  // ── ライトテーマ（テーマ切替 #45） ──────────────────────
  // 各ジョブのアクセント色（primary）はダーク版と共有し、
  // 背景のみ明るい和紙色へ差し替える。

  static const _paperWhite = Color(0xFFF7F3E8);
  static const _paperSurface = Color(0xFFEFE9D8);

  /// ライト時の本文色（和紙白に対する 12:1 前後）。
  static const _ink = Color(0xFF2B2B2B);

  static final _lightBase = ThemeData(
    brightness: Brightness.light,
    primaryColor: _gold,
    scaffoldBackgroundColor: _paperWhite,
    useMaterial3: true,
    // 明背景での文字色契約（ダークは ThemeData.dark の既定に委ねる）。
    textTheme: Typography.material2021()
        .black
        .apply(bodyColor: _ink, displayColor: _ink),
  );

  // ── ライト用ボタン契約 ──────────────────────────────────
  // 既定の ElevatedButton / FilledButton は前景に primary を採るため、
  // ライトの金 #D4A038 は和紙白地で 2.13:1 まで落ち、style 未指定の
  // ボタンがどの画面でも読めない。ライト時のみ「前景 ↔ 自分の塗り面」を
  // 4.5:1 以上に固定する。**ダークは ButtonStyle を一切設定しない**
  // （＝既定のまま。ダークの見た目は 1px も変わらない）。

  /// ライトのボタン前景に使う濃色（和紙白地 12.77:1）。
  static const _buttonInk = Color(0xFF1A1A1A);

  /// ボタン文字に使うライトの金（和紙白地 6.24:1）。
  static const _buttonAccent = Color(0xFF7A5200);

  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 塗り面 [fill] に対し 4.5:1 以上を満たす (塗り, 前景) の組を返す。
  /// 濃色前景 → 白前景 → 塗りの濃色化、の順に試す（決定的）。
  static ({Color fill, Color onFill}) _readablePair(Color fill) {
    if (_contrastRatio(_buttonInk, fill) >= 4.5) {
      return (fill: fill, onFill: _buttonInk);
    }
    if (_contrastRatio(Colors.white, fill) >= 4.5) {
      return (fill: fill, onFill: Colors.white);
    }
    for (double t = 0.05; t <= 0.95; t += 0.05) {
      final darkened = Color.lerp(fill, _buttonInk, t)!;
      if (_contrastRatio(Colors.white, darkened) >= 4.5) {
        return (fill: darkened, onFill: Colors.white);
      }
    }
    return (fill: fill, onFill: _buttonInk);
  }

  /// ライトテーマへボタン契約を付与する（ダークには適用しない）。
  static ThemeData _withLightButtonContract(ThemeData theme) {
    final scheme = theme.colorScheme;
    final filled = _readablePair(scheme.primary);
    return theme.copyWith(
      // 昇格ボタンは和紙色の面＋濃墨文字（既定の金文字 2.13:1 を回避）。
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(scheme.surface),
          foregroundColor: const WidgetStatePropertyAll<Color>(_buttonInk),
          iconColor: const WidgetStatePropertyAll<Color>(_buttonInk),
        ),
      ),
      // 塗りボタンは primary 面＋4.5:1 を満たす前景。
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(filled.fill),
          foregroundColor: WidgetStatePropertyAll<Color>(filled.onFill),
          iconColor: WidgetStatePropertyAll<Color>(filled.onFill),
        ),
      ),
      // 枠線ボタンは金文字をやめ、濃墨＋金枠へ。
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll<Color>(_buttonInk),
          iconColor: const WidgetStatePropertyAll<Color>(_buttonInk),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.primary),
          ),
        ),
      ),
      // 文字ボタンは可読な濃金（和紙白地 6.24:1）。
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(_buttonAccent),
          iconColor: WidgetStatePropertyAll<Color>(_buttonAccent),
        ),
      ),
    );
  }

  /// 浪人（ライト） — 和紙白基調、金アクセント
  static final adventurerLight = _withLightButtonContract(_lightBase.copyWith(
    appBarTheme:
        const AppBarTheme(backgroundColor: _paperSurface, elevation: 0),
    colorScheme: const ColorScheme.light(
        primary: _gold,
        onPrimary: _ink,
        secondary: _gold,
        surface: _paperSurface,
        onSurface: _ink,
        error: Color(0xFFC0392B)),
  ));

  /// 侍（ライト） — 白基調、朱アクセント
  static final warriorLight = _withLightButtonContract(_lightBase.copyWith(
    scaffoldBackgroundColor: const Color(0xFFFBF4F2),
    appBarTheme:
        const AppBarTheme(backgroundColor: Color(0xFFF2E2DE), elevation: 0),
    colorScheme: const ColorScheme.light(
        primary: Color(0xFFC0392B),
        onPrimary: Colors.white,
        secondary: _gold,
        surface: Color(0xFFF2E2DE),
        onSurface: _ink),
  ));

  /// 法師（ライト） — 白基調、青緑アクセント
  static final clericLight = _withLightButtonContract(_lightBase.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF0F6F5),
    appBarTheme:
        const AppBarTheme(backgroundColor: Color(0xFFDCEBE9), elevation: 0),
    colorScheme: const ColorScheme.light(
        primary: Color(0xFF2E8B82),
        onPrimary: Colors.white,
        secondary: _gold,
        surface: Color(0xFFDCEBE9),
        onSurface: _ink),
  ));

  /// 陰陽師（ライト） — 淡紫基調、金アクセント
  static final wizardLight = _withLightButtonContract(_lightBase.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF4F1FA),
    appBarTheme:
        const AppBarTheme(backgroundColor: Color(0xFFE5DEF5), elevation: 0),
    colorScheme: const ColorScheme.light(
        primary: _gold,
        onPrimary: _ink,
        secondary: Color(0xFF7E57C2),
        surface: Color(0xFFE5DEF5),
        onSurface: _ink),
  ));

  /// ジョブに応じたライトテーマを返す
  static ThemeData lightForJob(Job job) {
    return switch (job) {
      Job.samurai => warriorLight,
      Job.monk => clericLight,
      Job.mystic => wizardLight,
      Job.adventurer => adventurerLight,
    };
  }

  /// テーマモードに応じたテーマを返す（main.dart 配線用）
  static ThemeData forJobInMode(Job job, ThemeMode mode) {
    return mode == ThemeMode.light ? lightForJob(job) : forJob(job);
  }
}
