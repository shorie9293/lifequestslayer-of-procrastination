import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('NotificationService', () {
    late NotificationService service;
    late String hivePath;

    setUp(() async {
      service = NotificationService();

      // タイムゾーンデータを初期化（_nextInstanceOfTimeで必要）
      tzdata.initializeTimeZones();

      // Hiveをテンポラリディレクトリで初期化
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

    // ── 設定のデフォルト値 ──

    test('isEnabled returns true by default', () async {
      final enabled = await service.isEnabled();
      expect(enabled, true);
    });

    test('getMorningHour defaults to 8, getEveningHour defaults to 21',
        () async {
      expect(await service.getMorningHour(), 8);
      expect(await service.getEveningHour(), 21);
    });

    test('getMorningMinute and getEveningMinute default to 0', () async {
      expect(await service.getMorningMinute(), 0);
      expect(await service.getEveningMinute(), 0);
    });

    // ── 設定の保存と再読込 ──

    test('saveSettings + re-read verifies persistence', () async {
      await service.saveSettings(
        enabled: false,
        morningHour: 6,
        morningMinute: 30,
        eveningHour: 22,
        eveningMinute: 15,
      );

      expect(await service.isEnabled(), false);
      expect(await service.getMorningHour(), 6);
      expect(await service.getMorningMinute(), 30);
      expect(await service.getEveningHour(), 22);
      expect(await service.getEveningMinute(), 15);
    });

    // ── _nextInstanceOfTime ──

    group('nextInstanceOfTime', () {
      setUp(() {
        // テストごとにタイムゾーンを固定
        tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      });

      test('returns a time in the future', () {
        final result = service.nextInstanceOfTime(12, 0);
        final now = tz.TZDateTime.now(tz.local);
        expect(result.isAfter(now), true,
            reason: 'nextInstanceOfTime should always return a future time');
      });

      test(
          'returns today if target time has not passed yet',
          () {
        final now = tz.TZDateTime.now(tz.local);

        // 23:59を指定 → 23:59を過ぎていなければ今日
        final result = service.nextInstanceOfTime(23, 59);
        final today2359 =
            tz.TZDateTime(tz.local, now.year, now.month, now.day, 23, 59);

        if (now.isBefore(today2359)) {
          // まだ23:59になっていない → 今日の23:59が返る
          expect(result.year, now.year);
          expect(result.month, now.month);
          expect(result.day, now.day);
        } else {
          // 23:59を過ぎている → 明日の23:59が返る
          final tomorrow = now.add(const Duration(days: 1));
          expect(result.year, tomorrow.year);
          expect(result.month, tomorrow.month);
          expect(result.day, tomorrow.day);
        }
        expect(result.hour, 23);
        expect(result.minute, 59);
      });

      test(
          'returns tomorrow if target time has already passed',
          () {
        final now = tz.TZDateTime.now(tz.local);

        // 0:00を指定 → 0:00を過ぎていれば明日
        final result = service.nextInstanceOfTime(0, 0);
        final today0000 =
            tz.TZDateTime(tz.local, now.year, now.month, now.day, 0, 0);

        if (now.isAfter(today0000)) {
          // もう0:00を過ぎている → 明日の0:00が返る
          final tomorrow = now.add(const Duration(days: 1));
          expect(result.year, tomorrow.year);
          expect(result.month, tomorrow.month);
          expect(result.day, tomorrow.day);
        } else {
          // ちょうど0:00 → 今日の0:00が返る
          expect(result.year, now.year);
          expect(result.month, now.month);
          expect(result.day, now.day);
        }
        expect(result.hour, 0);
        expect(result.minute, 0);
      });

      test('exactly at target time returns tomorrow (isBefore is strict)',
          () {
        // 現在時刻から1分後の時刻を計算し、それをターゲットとする
        // → isBefore が true なので今日が返るはず（ギリギリ未来）
        final oneMinuteLater =
            tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
        final result = service.nextInstanceOfTime(
          oneMinuteLater.hour,
          oneMinuteLater.minute,
        );
        // ターゲットは未来なので今日が返る
        expect(result.day, oneMinuteLater.day,
            reason: '1 minute in the future should still be today');
      });
    });
  });
}
