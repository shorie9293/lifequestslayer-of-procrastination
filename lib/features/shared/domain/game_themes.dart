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
    appBarTheme: const AppBarTheme(
      backgroundColor: _deepPurple, elevation: 0),
    colorScheme: const ColorScheme.dark(
      primary: _gold, secondary: _gold,
      surface: _washiDark, error: Color(0xFFE85050)),
  );

  /// 侍 — 墨黒基調、朱アクセント
  static final warrior = _base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF1A0D0D),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2A1010), elevation: 0),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFE85050), secondary: _gold,
      surface: Color(0xFF2A1A1A)),
  );

  /// 法師 — 墨黒基調、青緑アクセント
  static final cleric = _base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF0D1A1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF102A2A), elevation: 0),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4DB6AC), secondary: _gold,
      surface: Color(0xFF1A2A2A)),
  );

  /// 陰陽師 — 深紫基調、金アクセント
  static final wizard = _base.copyWith(
    scaffoldBackgroundColor: _deepPurple,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF261650), elevation: 0),
    colorScheme: const ColorScheme.dark(
      primary: _gold, secondary: Color(0xFFBB86FC),
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

  static final _lightBase = ThemeData(
    brightness: Brightness.light,
    primaryColor: _gold,
    scaffoldBackgroundColor: _paperWhite,
    useMaterial3: true,
  );

  /// 浪人（ライト） — 和紙白基調、金アクセント
  static final adventurerLight = _lightBase.copyWith(
    appBarTheme: const AppBarTheme(
        backgroundColor: _paperSurface, elevation: 0),
    colorScheme: const ColorScheme.light(
      primary: _gold, secondary: _gold,
      surface: _paperSurface, error: Color(0xFFC0392B)),
  );

  /// 侍（ライト） — 白基調、朱アクセント
  static final warriorLight = _lightBase.copyWith(
    scaffoldBackgroundColor: const Color(0xFFFBF4F2),
    appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2E2DE), elevation: 0),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFC0392B), secondary: _gold,
      surface: Color(0xFFF2E2DE)),
  );

  /// 法師（ライト） — 白基調、青緑アクセント
  static final clericLight = _lightBase.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF0F6F5),
    appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFDCEBE9), elevation: 0),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2E8B82), secondary: _gold,
      surface: Color(0xFFDCEBE9)),
  );

  /// 陰陽師（ライト） — 淡紫基調、金アクセント
  static final wizardLight = _lightBase.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF4F1FA),
    appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFE5DEF5), elevation: 0),
    colorScheme: const ColorScheme.light(
      primary: _gold, secondary: Color(0xFF7E57C2),
      surface: Color(0xFFE5DEF5)),
  );

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
