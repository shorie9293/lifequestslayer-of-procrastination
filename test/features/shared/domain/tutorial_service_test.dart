import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/tutorial_service.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  late Directory testDir;

  setUpAll(() async {
    testDir = Directory(
        '${Directory.systemTemp.path}/tutorial_service_test_${DateTime.now().millisecondsSinceEpoch}');
    Hive.init(testDir.path);
  });

  setUp(() async {
    try {
      await Hive.deleteBoxFromDisk('tutorialBox');
      await Hive.deleteBoxFromDisk('settingsBox');
    } catch (_) {}
  });

  tearDownAll(() async {
    await Hive.close();
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('SettingsRepository - jobTutorialCompleted', () {
    test('初期値はfalse', () async {
      final repo = SettingsRepository();
      final value = await repo.getJobTutorialCompleted();
      expect(value, false);
    });

    test('trueに設定して読み戻せる', () async {
      final repo = SettingsRepository();
      await repo.setJobTutorialCompleted(true);
      final value = await repo.getJobTutorialCompleted();
      expect(value, true);
    });

    test('true→falseに戻せる', () async {
      final repo = SettingsRepository();
      await repo.setJobTutorialCompleted(true);
      await repo.setJobTutorialCompleted(false);
      final value = await repo.getJobTutorialCompleted();
      expect(value, false);
    });
  });

  group('TutorialService - markJobTutorialSeen', () {
    test('未完了→完了でtrueが返る', () async {
      final repo = SettingsRepository();
      final service = TutorialService(repo);
      final result = await service.markJobTutorialSeen(false);
      expect(result, true);
      final persisted = await repo.getJobTutorialCompleted();
      expect(persisted, true);
    });

    test('既に完了済みの場合falseが返る', () async {
      final repo = SettingsRepository();
      await repo.setJobTutorialCompleted(true);
      final service = TutorialService(repo);
      final result = await service.markJobTutorialSeen(true);
      expect(result, false);
    });
  });
}
