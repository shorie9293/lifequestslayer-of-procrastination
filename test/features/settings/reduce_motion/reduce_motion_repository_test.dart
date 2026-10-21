import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';

void main() {
  group('InMemoryReduceMotionRepository', () {
    test('未保存の load は null を返す', () async {
      final repo = InMemoryReduceMotionRepository();
      expect(await repo.load(), isNull);
    });

    test('save → load で往復し、saved と saveCount が更新される', () async {
      final repo = InMemoryReduceMotionRepository();
      await repo.save(ReduceMotionSetting.on);
      expect(await repo.load(), ReduceMotionSetting.on);
      expect(repo.saved, ReduceMotionSetting.on);
      expect(repo.saveCount, 1);

      await repo.save(ReduceMotionSetting.off);
      expect(await repo.load(), ReduceMotionSetting.off);
      expect(repo.saveCount, 2);
    });
  });

  group('HiveReduceMotionRepository', () {
    late HiveReduceMotionRepository repo;

    setUpAll(() async {
      final testDir = Directory(
          '${Directory.systemTemp.path}/reduce_motion_repo_test_${DateTime.now().millisecondsSinceEpoch}');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      Hive.init(testDir.path);
    });

    setUp(() async {
      repo = const HiveReduceMotionRepository();
      await Hive.openBox(HiveReduceMotionRepository.boxName);
    });

    tearDown(() async {
      try {
        await Hive.close();
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk(HiveReduceMotionRepository.boxName);
      } catch (_) {}
    });

    test('未保存の load は null を返す（system 扱い）', () async {
      expect(await repo.load(), isNull);
    });

    test('save → load で storageKey 経由で往復する', () async {
      await repo.save(ReduceMotionSetting.on);
      final box = Hive.box(HiveReduceMotionRepository.boxName);
      expect(box.get(HiveReduceMotionRepository.storageKey), 'on');
      expect(await repo.load(), ReduceMotionSetting.on);

      await repo.save(ReduceMotionSetting.off);
      expect(await repo.load(), ReduceMotionSetting.off);
    });

    test('未知の保存値は null（system 扱い）に落ちる', () async {
      final box = Hive.box(HiveReduceMotionRepository.boxName);
      await box.put(HiveReduceMotionRepository.storageKey, 'legacy-garbage');
      expect(await repo.load(), isNull);
    });

    test('非文字列の破損値も null（system 扱い）に落ちる', () async {
      final box = Hive.box(HiveReduceMotionRepository.boxName);
      await box.put(HiveReduceMotionRepository.storageKey, 42);
      expect(await repo.load(), isNull);
    });
  });
}
