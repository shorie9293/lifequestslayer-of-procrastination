import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 改善提案#67: 効果音の音量設定（Repository / ViewModel の永続化）
void main() {
  late String hivePath;

  setUp(() async {
    hivePath =
        '${Directory.systemTemp.path}/hive_sfxvol_${DateTime.now().microsecondsSinceEpoch}';
    Hive.init(hivePath);
  });

  tearDown(() async {
    await Hive.close();
    final dir = Directory(hivePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('SettingsRepository - 効果音の音量', () {
    test('既定値は SfxVolumeSetting.defaultValue', () async {
      final repository = SettingsRepository();
      expect(await repository.getSfxVolume(), SfxVolumeSetting.defaultValue);
    });

    test('設定した値が別インスタンスの Repository から再読込できる', () async {
      final repository = SettingsRepository();
      await repository.setSfxVolume(0.25);
      final reloaded = SettingsRepository();
      expect(await reloaded.getSfxVolume(), 0.25);
    });

    test('範囲外の値を保存してもクランプされる', () async {
      final repository = SettingsRepository();
      await repository.setSfxVolume(2.0);
      expect(await repository.getSfxVolume(), SfxVolumeSetting.maxValue);
      await repository.setSfxVolume(-1.0);
      expect(await repository.getSfxVolume(), SfxVolumeSetting.minValue);
    });

    test('破損値（文字列）は既定値へ安全フォールバックする', () async {
      final repository = SettingsRepository();
      final box = await Hive.openBox('settingsBox');
      await box.put(SfxVolumeSetting.storageKey, '壊れた値');
      expect(await repository.getSfxVolume(), SfxVolumeSetting.defaultValue);
    });

    test('破損値（範囲外の数値）は既定値へ安全フォールバックする', () async {
      final repository = SettingsRepository();
      final box = await Hive.openBox('settingsBox');
      await box.put(SfxVolumeSetting.storageKey, 9.9);
      expect(await repository.getSfxVolume(), SfxVolumeSetting.defaultValue);
    });

    test('sfxEnabled と sfxVolume は独立して永続化される', () async {
      final repository = SettingsRepository();
      await repository.setSfxEnabled(false);
      await repository.setSfxVolume(0.5);
      expect(await repository.getSfxEnabled(), false);
      expect(await repository.getSfxVolume(), 0.5);
    });
  });

  group('SettingsViewModel - 効果音の音量', () {
    test('既定値は SfxVolumeSetting.defaultValue', () {
      final vm = SettingsViewModel(SettingsRepository());
      expect(vm.sfxVolume, SfxVolumeSetting.defaultValue);
    });

    test('setSfxVolume はクランプして状態と永続化の双方へ反映する', () async {
      final vm = SettingsViewModel(SettingsRepository());
      await vm.setSfxVolume(2.0);
      expect(vm.sfxVolume, SfxVolumeSetting.maxValue);
      // 別インスタンスの Repository から再読込＝本当に保存されたか
      expect(await SettingsRepository().getSfxVolume(),
          SfxVolumeSetting.maxValue);
    });

    test('setSfxVolume は通知を発火する', () async {
      final vm = SettingsViewModel(SettingsRepository());
      var notified = 0;
      vm.addListener(() => notified++);
      await vm.setSfxVolume(0.75);
      expect(notified, greaterThan(0));
    });

    test('load() が永続値を読み戻す', () async {
      await SettingsRepository().setSfxVolume(0.25);
      final vm = SettingsViewModel(SettingsRepository());
      await vm.load();
      expect(vm.sfxVolume, 0.25);
    });
  });
}
