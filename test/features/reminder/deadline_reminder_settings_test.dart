import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';

void main() {
  group('DeadlineReminderSettings', () {
    test('既定は無効・8:00・3日以内', () {
      final s = DeadlineReminderSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.hour, 8);
      expect(s.minute, 0);
      expect(s.withinDays, 3);
      expect(s.updatedAt, isNull);
    });

    test('時刻・対象日数の範囲外は ArgumentError', () {
      expect(() => DeadlineReminderSettings(hour: 24), throwsArgumentError);
      expect(() => DeadlineReminderSettings(hour: -1), throwsArgumentError);
      expect(() => DeadlineReminderSettings(minute: 60), throwsArgumentError);
      expect(
        () => DeadlineReminderSettings(withinDays: 0),
        throwsArgumentError,
      );
      expect(
        () => DeadlineReminderSettings(withinDays: 31),
        throwsArgumentError,
      );
    });

    test('copyWith は指定項目のみ差し替える', () {
      final base = DeadlineReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        withinDays: 7,
      );
      final updated = base.copyWith(minute: 45);
      expect(updated.enabled, isTrue);
      expect(updated.hour, 7);
      expect(updated.minute, 45);
      expect(updated.withinDays, 7);
    });

    test('JSON 往復', () {
      final s = DeadlineReminderSettings(
        enabled: true,
        hour: 21,
        minute: 5,
        withinDays: 7,
        updatedAt: DateTime(2026, 10, 18, 9, 30),
      );
      final restored = DeadlineReminderSettings.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(restored, s);
    });

    test('型不一致は FormatException', () {
      expect(
        () => DeadlineReminderSettings.fromJson({
          'enabled': 1,
          'hour': 8,
          'minute': 0,
          'withinDays': 3,
        }),
        throwsFormatException,
      );
      expect(
        () => DeadlineReminderSettings.fromJson({
          'enabled': true,
          'hour': 8,
          'minute': 0,
        }),
        throwsFormatException,
      );
    });

    test('範囲外の値は FormatException（呼び出し側は既定へフォールバック）', () {
      expect(
        () => DeadlineReminderSettings.fromJson({
          'enabled': true,
          'hour': 25,
          'minute': 0,
          'withinDays': 3,
        }),
        throwsFormatException,
      );
      expect(
        () => DeadlineReminderSettings.fromJson({
          'enabled': true,
          'hour': 8,
          'minute': 0,
          'withinDays': 0,
        }),
        throwsFormatException,
      );
    });

    test('等価性: 同値は等しく、1項目違えば異なる', () {
      final a = DeadlineReminderSettings(enabled: true);
      final b = DeadlineReminderSettings(enabled: true);
      final c = a.copyWith(withinDays: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
