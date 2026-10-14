import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/services/backup_registry.dart';

void main() {
  group('BackupBoxRegistry', () {
    test('specs are enumerated (one spec per documented box)', () {
      // 仕様表の全 box（playerBox/tasksBox 等の除外boxを除く）
      expect(BackupBoxRegistry.specs, isNotEmpty);
      expect(BackupBoxRegistry.count, BackupBoxRegistry.specs.length);
    });

    test('specs contain all documented box names', () {
      final names = BackupBoxRegistry.boxNames;
      for (final name in [
        'battle_records',
        'practice_logs',
        'task_time_records',
        'task_templates',
        'reminderBox',
        'gryphon_reports',
        'settingsBox',
        'notification_settings',
        'crossAppSettings',
        'tutorialBox',
        'townBox',
        'reflections',
        'reflectionsBox',
      ]) {
        expect(names, contains(name), reason: '$name が registry に無い');
      }
    });

    test('excluded boxes are NOT in registry', () {
      final names = BackupBoxRegistry.boxNames;
      expect(names, isNot(contains('playerBox')));
      expect(names, isNot(contains('tasksBox')));
      expect(names, isNot(contains('playerBox_backup')));
      expect(names, isNot(contains('tasksBox_backup')));
      expect(names, isNot(contains('featureFlagsBox')));
      expect(names, isNot(contains('iapPendingBox')));
    });

    test('boxNames has no duplicates', () {
      final names = BackupBoxRegistry.boxNames;
      expect(names.toSet().length, names.length);
    });

    test('specFor returns spec for known box, null for unknown', () {
      final spec = BackupBoxRegistry.specFor('battle_records');
      expect(spec, isNotNull);
      expect(spec!.kind, BackupBoxKind.jsonValue);
      expect(spec.label, isNotEmpty);

      expect(BackupBoxRegistry.specFor('reflections')!.kind,
          BackupBoxKind.reflectionObject);

      expect(BackupBoxRegistry.specFor('unknown_box'), isNull);
      expect(BackupBoxRegistry.specFor('playerBox'), isNull);
    });

    test('isBackupTarget matches registry membership', () {
      expect(BackupBoxRegistry.isBackupTarget('settingsBox'), isTrue);
      expect(BackupBoxRegistry.isBackupTarget('reflectionsBox'), isTrue);
      expect(BackupBoxRegistry.isBackupTarget('tasksBox'), isFalse);
      expect(BackupBoxRegistry.isBackupTarget('no_such_box'), isFalse);
    });

    test('every spec has non-empty Japanese label', () {
      for (final spec in BackupBoxRegistry.specs) {
        expect(spec.label, isNotEmpty, reason: '${spec.boxName} の label が空');
      }
    });
  });
}
