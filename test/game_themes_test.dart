import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

void main() {
  group('GameThemes', () {
    test('adventurer（浪人）テーマは深紫基調', () {
      final theme = GameThemes.forJob(Job.adventurer);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0D0D1A));
    });

    test('warrior（侍）テーマは墨黒基調', () {
      final theme = GameThemes.forJob(Job.warrior);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A0D0D));
    });

    test('cleric（法師）テーマは青緑アクセント', () {
      final theme = GameThemes.forJob(Job.cleric);
      expect(theme.brightness, Brightness.dark);
      final primary = theme.colorScheme.primary;
      expect(primary, const Color(0xFF4DB6AC));
    });

    test('wizard（陰陽師）テーマは深紫基調に金アクセント', () {
      final theme = GameThemes.forJob(Job.wizard);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1040));
      expect(theme.colorScheme.primary, const Color(0xFFD4A038));
    });

    test('各ジョブで異なるテーマが返される', () {
      final themes = Job.values.map((j) => GameThemes.forJob(j));
      // 少なくとも2つ以上の異なる scaffoldBackgroundColor がある
      final bgColors = themes.map((t) => t.scaffoldBackgroundColor).toSet();
      expect(bgColors.length, greaterThanOrEqualTo(2));
    });
  });
}
