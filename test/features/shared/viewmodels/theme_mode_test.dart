import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';

void main() {
  group('ThemeModePersistence', () {
    late SettingsRepository repository;
    late String hivePath;

    setUp(() async {
      repository = SettingsRepository();
      hivePath =
          '${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}';
      Hive.init(hivePath);
    });

    tearDown(() async {
      await Hive.close();
      final dir = Directory(hivePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('テーマモードは既定で dark（現行仕様の維持）', () async {
      expect(await repository.getThemeMode(), ThemeMode.dark);
    });

    test('テーマモードを保存・再読込できる', () async {
      await repository.setThemeMode(ThemeMode.light);
      expect(await repository.getThemeMode(), ThemeMode.light);
      await repository.setThemeMode(ThemeMode.dark);
      expect(await repository.getThemeMode(), ThemeMode.dark);
    });

    test('不正な保存値は dark へフォールバックする', () async {
      final box = await Hive.openBox('settingsBox');
      await box.put('themeMode', 'corrupted');
      expect(await repository.getThemeMode(), ThemeMode.dark);
    });
  });

  group('ThemeModeViewModel', () {
    late SettingsRepository repository;
    late String hivePath;

    setUp(() async {
      repository = SettingsRepository();
      hivePath =
          '${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}2';
      Hive.init(hivePath);
    });

    tearDown(() async {
      await Hive.close();
      final dir = Directory(hivePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('既定は dark・setThemeMode で状態と永続が更新される', () async {
      final vm = SettingsViewModel(repository);
      expect(vm.themeMode, ThemeMode.dark);
      await vm.setThemeMode(ThemeMode.light);
      expect(vm.themeMode, ThemeMode.light);
      expect(await repository.getThemeMode(), ThemeMode.light);
    });

    test('load() で保存済みテーマモードが復元される', () async {
      await repository.setThemeMode(ThemeMode.light);
      final vm = SettingsViewModel(repository);
      await vm.load();
      expect(vm.themeMode, ThemeMode.light);
    });
  });

  group('GameThemes lightForJob', () {
    test('ライト版は明るい背景と ColorScheme.light を持つ', () {
      for (final job in Job.values) {
        final theme = GameThemes.lightForJob(job);
        expect(theme.brightness, Brightness.light,
            reason: 'job=$job のライトテーマが dark になっている');
        expect(theme.colorScheme.brightness, Brightness.light,
            reason: 'job=$job の colorScheme が light になっていない');
      }
    });

    test('ライト版は濃色アクセント（白背景での視認性確保のため色調整済み）', () {
      expect(GameThemes.lightForJob(Job.adventurer).colorScheme.primary,
          const Color(0xFFD4A038));
      expect(GameThemes.lightForJob(Job.samurai).colorScheme.primary,
          const Color(0xFFC0392B));
      expect(GameThemes.lightForJob(Job.monk).colorScheme.primary,
          const Color(0xFF2E8B82));
      expect(GameThemes.lightForJob(Job.mystic).colorScheme.primary,
          const Color(0xFFD4A038));
    });

    test('ライト版の背景は明るい色である', () {
      final bg = GameThemes.lightForJob(Job.adventurer).scaffoldBackgroundColor;
      expect(bg.computeLuminance() > 0.5, isTrue);
    });
  });
}
