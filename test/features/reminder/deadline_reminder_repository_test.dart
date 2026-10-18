import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/data/deadline_reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';

void main() {
  group('InMemoryDeadlineReminderRepository', () {
    test('save → load の往復', () async {
      final repo = InMemoryDeadlineReminderRepository();
      final s = DeadlineReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        withinDays: 7,
      );
      await repo.save(s);
      expect(await repo.load(), s);
    });

    test('初期値を注入できる', () async {
      final initial =
          DeadlineReminderSettings(enabled: true, hour: 21, withinDays: 1);
      final repo = InMemoryDeadlineReminderRepository(initial);
      expect(await repo.load(), initial);
    });

    test('既定では defaults', () async {
      final repo = InMemoryDeadlineReminderRepository();
      expect(await repo.load(), DeadlineReminderSettings.defaults());
    });
  });

  group('永続キーの独立', () {
    test('勤行リマインダーとは別キーである', () {
      expect(HiveDeadlineReminderRepository.keyName, 'deadlineReminder');
      // 同一 box を共用しつつキーが異なる（片方の保存が他方を壊さない）。
      expect(HiveDeadlineReminderRepository.boxName, 'reminderBox');
    });

    test('JSON 化しても勤行リマインダーのキーを含まない', () {
      final json = DeadlineReminderSettings(enabled: true).toJson();
      expect(json.containsKey('weekdays'), isFalse);
      expect(json.keys.toSet(), {
        'enabled',
        'hour',
        'minute',
        'withinDays',
        'updatedAt',
      });
      expect(jsonEncode(json), isNotEmpty);
    });
  });
}
