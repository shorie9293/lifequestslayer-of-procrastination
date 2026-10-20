import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_settings.dart';

void main() {
  group('QuietHoursPolicy', () {
    test('storageKey と label', () {
      expect(QuietHoursPolicy.defer.storageKey, 'defer');
      expect(QuietHoursPolicy.defer.label, '翌朝に繰り延べ');
      expect(QuietHoursPolicy.skip.storageKey, 'skip');
      expect(QuietHoursPolicy.skip.label, '通知しない');
    });

    test('fromStorageKey: 未知は defer', () {
      expect(QuietHoursPolicy.fromStorageKey('defer'), QuietHoursPolicy.defer);
      expect(QuietHoursPolicy.fromStorageKey('skip'), QuietHoursPolicy.skip);
      expect(QuietHoursPolicy.fromStorageKey('bogus'), QuietHoursPolicy.defer);
      expect(QuietHoursPolicy.fromStorageKey(null), QuietHoursPolicy.defer);
    });
  });

  group('QuietHoursSettings', () {
    test('defaults は 無効・22:00-07:00・defer', () {
      final s = QuietHoursSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.startHour, 22);
      expect(s.startMinute, 0);
      expect(s.endHour, 7);
      expect(s.endMinute, 0);
      expect(s.policy, QuietHoursPolicy.defer);
    });

    test('startMinutes / endMinutes / ラベル', () {
      final s = QuietHoursSettings(
        startHour: 22,
        startMinute: 30,
        endHour: 7,
        endMinute: 5,
      );
      expect(s.startMinutes, 22 * 60 + 30);
      expect(s.endMinutes, 7 * 60 + 5);
      expect(s.startLabel, '22:30');
      expect(s.endLabel, '07:05');
    });

    test('範囲外の時刻は ArgumentError', () {
      expect(
        () => QuietHoursSettings(startHour: 24),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => QuietHoursSettings(startHour: -1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => QuietHoursSettings(startMinute: 60),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => QuietHoursSettings(endHour: 24),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => QuietHoursSettings(endMinute: 60),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('値等価 ==/hashCode', () {
      final a = QuietHoursSettings(
        enabled: true,
        startHour: 21,
        startMinute: 15,
        endHour: 6,
        endMinute: 45,
        policy: QuietHoursPolicy.skip,
      );
      final b = QuietHoursSettings(
        enabled: true,
        startHour: 21,
        startMinute: 15,
        endHour: 6,
        endMinute: 45,
        policy: QuietHoursPolicy.skip,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(startMinute: 16), isFalse);
    });

    test('copyWith は指定値のみ差し替え', () {
      final s = QuietHoursSettings.defaults().copyWith(
        enabled: true,
        endHour: 8,
        policy: QuietHoursPolicy.skip,
      );
      expect(s.enabled, isTrue);
      expect(s.endHour, 8);
      expect(s.endMinute, 0);
      expect(s.policy, QuietHoursPolicy.skip);
      expect(s.startHour, 22);
    });

    test('toJson / fromJson 往復', () {
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 23,
        startMinute: 10,
        endHour: 6,
        endMinute: 20,
        policy: QuietHoursPolicy.skip,
      );
      expect(QuietHoursSettings.fromJson(s.toJson()), s);
    });

    test('fromJson: 破損・型不正は defaults へフォールバック', () {
      expect(
          QuietHoursSettings.fromJson(const {}), QuietHoursSettings.defaults());
      expect(
        QuietHoursSettings.fromJson(const {'enabled': 'yes'}),
        QuietHoursSettings.defaults(),
      );
      expect(
        QuietHoursSettings.fromJson(const {'startHour': '22'}),
        QuietHoursSettings.defaults(),
      );
      expect(
        QuietHoursSettings.fromJson(const {'startHour': 99}),
        QuietHoursSettings.defaults(),
      );
      expect(
        QuietHoursSettings.fromJson(const {'policy': 'unknown'}),
        QuietHoursSettings.defaults(),
      );
    });
  });
}
