import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/reminder/data/quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/hive_quiet_hours_repository.dart';

void main() {
  group('InMemoryQuietHoursRepository', () {
    test('load は初期値を返し、save が反映される', () async {
      final repo = InMemoryQuietHoursRepository();
      expect(await repo.load(), QuietHoursSettings.defaults());
      final s = QuietHoursSettings.defaults().copyWith(enabled: true);
      await repo.save(s);
      expect(await repo.load(), s);
    });

    test('loadCount / saveCount を観測できる', () async {
      final repo = InMemoryQuietHoursRepository();
      await repo.load();
      await repo.save(QuietHoursSettings.defaults());
      expect(repo.loadCount, 1);
      expect(repo.saveCount, 1);
    });
  });

  test('NoopQuietHoursRepository は defaults 固定・保存は捨てる', () async {
    final repo = NoopQuietHoursRepository();
    await repo.save(QuietHoursSettings.defaults().copyWith(enabled: true));
    expect(await repo.load(), QuietHoursSettings.defaults());
  });

  group('HiveQuietHoursRepository', () {
    late Directory dir;

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('quiet_hours_repo_test');
      Hive.init(dir.path);
    });

    tearDownAll(() async {
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('保存した設定が別インスタンスで復元される', () async {
      final repo = HiveQuietHoursRepository();
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 21,
        startMinute: 30,
        endHour: 6,
        endMinute: 45,
        policy: QuietHoursPolicy.skip,
      );
      await repo.save(s);

      final reopened = HiveQuietHoursRepository();
      expect(await reopened.load(), s);
    });

    test('破損した JSON は defaults へフォールバック', () async {
      final box = await Hive.openBox<String>(
        HiveQuietHoursRepository.boxName,
      );
      await box.put(HiveQuietHoursRepository.keyName, '{not json');
      final repo = HiveQuietHoursRepository(box: box);
      expect(await repo.load(), QuietHoursSettings.defaults());
    });

    test('未保存（キー欠落）は defaults へフォールバック', () async {
      final box = await Hive.openBox<String>(
        HiveQuietHoursRepository.boxName,
      );
      await box.delete(HiveQuietHoursRepository.keyName);
      final repo = HiveQuietHoursRepository(box: box);
      expect(await repo.load(), QuietHoursSettings.defaults());
    });

    test('注入した box に JSON 文字列で保存する', () async {
      final box = await Hive.openBox<String>(
        HiveQuietHoursRepository.boxName,
      );
      final repo = HiveQuietHoursRepository(box: box);
      await repo.save(
        QuietHoursSettings.defaults().copyWith(policy: QuietHoursPolicy.skip),
      );
      final raw = box.get(HiveQuietHoursRepository.keyName);
      expect(raw, isA<String>());
      expect(raw, contains('"policy":"skip"'));
    });
  });
}
