import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/data/reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';

void main() {
  group('InMemoryReminderRepository', () {
    test('save → load の往復', () async {
      final repo = InMemoryReminderRepository();
      final s = ReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        weekdays: [1, 3, 5],
      );
      await repo.save(s);
      expect(await repo.load(), s);
    });

    test('初期値を注入できる', () async {
      final initial = ReminderSettings(enabled: true, weekdays: [6]);
      final repo = InMemoryReminderRepository(initial);
      expect(await repo.load(), initial);
    });

    test('既定では defaults', () async {
      final repo = InMemoryReminderRepository();
      expect(await repo.load(), ReminderSettings.defaults());
    });
  });

  group('ReminderSettings JSON ロジック（フォールバックの素となる挙動）', () {
    test('正しいJSONは復元できる', () {
      final json = jsonEncode({
        'enabled': true,
        'hour': 7,
        'minute': 15,
        'weekdays': [1, 3, 5],
        'updatedAt': null,
      });
      final s = ReminderSettings.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(s.enabled, isTrue);
      expect(s.hour, 7);
      expect(s.minute, 15);
      expect(s.weekdays, [1, 3, 5]);
    });

    test('破損JSON（型不一致）は FormatException → 呼び出し側は defaults にフォールバック', () {
      final broken = jsonDecode(jsonEncode({
        'enabled': 1, // 型不一致
        'hour': 7,
        'minute': 15,
        'weekdays': [1],
      })) as Map<String, dynamic>;
      ReminderSettings restored;
      try {
        restored = ReminderSettings.fromJson(broken);
        fail('should throw');
      } on FormatException {
        restored = ReminderSettings.defaults();
      }
      expect(restored, ReminderSettings.defaults());
    });

    test('範囲外の値は FormatException', () {
      expect(
        () => ReminderSettings.fromJson({
          'enabled': true,
          'hour': 25,
          'minute': 0,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
    });
  });
}
