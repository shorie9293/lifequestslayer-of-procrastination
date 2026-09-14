import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';

void main() {
  group('ReminderSettings 既定値', () {
    test('defaults は無効・6:30・毎日', () {
      final s = ReminderSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.hour, 6);
      expect(s.minute, 30);
      expect(s.weekdays, [1, 2, 3, 4, 5, 6, 7]);
      expect(s.updatedAt, isNull);
      expect(s.isDaily, isTrue);
    });

    test('weekdays が6件なら isDaily は false', () {
      final s = ReminderSettings(weekdays: [1, 2, 3, 4, 5, 6]);
      expect(s.isDaily, isFalse);
    });

    test('空 weekdays は許容される（通知日なし）', () {
      expect(() => ReminderSettings(weekdays: []), returnsNormally);
    });
  });

  group('ReminderSettings 検証', () {
    test('hour が範囲外なら ArgumentError', () {
      expect(() => ReminderSettings(hour: -1), throwsArgumentError);
      expect(() => ReminderSettings(hour: 24), throwsArgumentError);
    });

    test('minute が範囲外なら ArgumentError', () {
      expect(() => ReminderSettings(minute: -1), throwsArgumentError);
      expect(() => ReminderSettings(minute: 60), throwsArgumentError);
    });

    test('weekday が範囲外なら ArgumentError', () {
      expect(() => ReminderSettings(weekdays: [0]), throwsArgumentError);
      expect(() => ReminderSettings(weekdays: [8]), throwsArgumentError);
    });
  });

  group('ReminderSettings JSON', () {
    test('toJson / fromJson の往復', () {
      final s = ReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        weekdays: [1, 3, 5],
        updatedAt: DateTime(2026, 9, 15, 8, 0),
      );
      final restored = ReminderSettings.fromJson(s.toJson());
      expect(restored, s);
    });

    test('fromJson: enabled 欠落は FormatException', () {
      expect(
        () => ReminderSettings.fromJson({'hour': 6, 'minute': 30, 'weekdays': [1]}),
        throwsFormatException,
      );
    });

    test('fromJson: 型不一致は FormatException', () {
      expect(
        () => ReminderSettings.fromJson({
          'enabled': 'yes',
          'hour': 6,
          'minute': 30,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
      expect(
        () => ReminderSettings.fromJson({
          'enabled': true,
          'hour': '6',
          'minute': 30,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
      expect(
        () => ReminderSettings.fromJson({
          'enabled': true,
          'hour': 6,
          'minute': 30,
          'weekdays': '1,2',
        }),
        throwsFormatException,
      );
    });

    test('fromJson: 範囲外は FormatException', () {
      expect(
        () => ReminderSettings.fromJson({
          'enabled': true,
          'hour': 99,
          'minute': 30,
          'weekdays': [1],
        }),
        throwsFormatException,
      );
    });
  });

  group('ReminderSettings copyWith', () {
    test('一部フィールドのみ更新し、他は保持する', () {
      final base = ReminderSettings.defaults();
      final updated = base.copyWith(enabled: true, hour: 7);
      expect(updated.enabled, isTrue);
      expect(updated.hour, 7);
      expect(updated.minute, 30);
      expect(updated.weekdays, base.weekdays);
    });

    test('weekdays の差し替え', () {
      final base = ReminderSettings.defaults();
      final updated = base.copyWith(weekdays: [6, 7]);
      expect(updated.weekdays, [6, 7]);
      expect(base.weekdays, [1, 2, 3, 4, 5, 6, 7]);
    });
  });

  group('ReminderSettings weekdays 不変性', () {
    test('外部から渡したリストを書き換えても設定は無影響', () {
      final weekdays = [1, 2, 3];
      final s = ReminderSettings(weekdays: weekdays);
      weekdays.add(4);
      expect(s.weekdays, [1, 2, 3]);
    });

    test('保持している weekdays は unmodifiable', () {
      final s = ReminderSettings(weekdays: [1, 2]);
      expect(
        () => s.weekdays.add(3),
        throwsUnsupportedError,
      );
    });
  });

  group('ReminderSettings 等価性', () {
    test('同一内容は == かつ hashCode 一致', () {
      final a = ReminderSettings(enabled: true, weekdays: [1, 3]);
      final b = ReminderSettings(enabled: true, weekdays: [1, 3]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('updatedAt が異なれば不一致', () {
      final a = ReminderSettings(updatedAt: DateTime(2026, 1, 1));
      final b = ReminderSettings(updatedAt: DateTime(2026, 1, 2));
      expect(a, isNot(b));
    });
  });
}
