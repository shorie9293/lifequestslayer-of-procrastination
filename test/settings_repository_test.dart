import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';

void main() {
  group('SettingsRepository - 通知設定', () {
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

    test('morningNotificationEnabled defaults to true', () async {
      final enabled = await repository.getMorningNotificationEnabled();
      expect(enabled, true);
    });

    test('eveningNotificationEnabled defaults to true', () async {
      final enabled = await repository.getEveningNotificationEnabled();
      expect(enabled, true);
    });

    test('morningNotificationEnabled can be set to false and re-read', () async {
      await repository.setMorningNotificationEnabled(false);
      final enabled = await repository.getMorningNotificationEnabled();
      expect(enabled, false);
    });

    test('eveningNotificationEnabled can be set to false and re-read', () async {
      await repository.setEveningNotificationEnabled(false);
      final enabled = await repository.getEveningNotificationEnabled();
      expect(enabled, false);
    });

    test('individual flags are independent', () async {
      await repository.setMorningNotificationEnabled(false);
      await repository.setEveningNotificationEnabled(true);
      expect(await repository.getMorningNotificationEnabled(), false);
      expect(await repository.getEveningNotificationEnabled(), true);
    });
  });
}
