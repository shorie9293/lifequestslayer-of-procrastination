import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';

/// consumePendingGems() の二重消費防止と冪等性を検証する。
/// initializeForTest() で Hive box を注入し、InAppPurchase を一切介さずテストする。
void main() {
  group('IAPService consumePendingGems', () {
    late IAPService iap;
    late Directory testDir;

    setUpAll(() async {
      testDir = Directory(
          '${Directory.systemTemp.path}/hive_iap_test_${DateTime.now().millisecondsSinceEpoch}');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      Hive.init(testDir.path);
    });

    setUp(() async {
      iap = IAPService();
      final box = await Hive.openBox('iapPendingBox');
      await iap.initializeForTest(box);
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('iapPendingBox');
    });

    test('購入前は consumePendingGems は 0 を返す', () async {
      final result = await iap.consumePendingGems();
      expect(result, 0);
    });

    test('購入後は consumePendingGems で宝石数を取得しリセットされる', () async {
      // Hive に直接書き込んで購入後の状態を模擬
      final box = await Hive.openBox('iapPendingBox');
      await box.put('pendingGems', 100);
      await iap.initializeForTest(box);

      final gems = await iap.consumePendingGems();
      expect(gems, 100);

      // 2回目の呼び出しは0を返す（すでに消費済み）
      final second = await iap.consumePendingGems();
      expect(second, 0);
    });

    test('_isConsuming フラグが二重消費を防止する', () async {
      final box = await Hive.openBox('iapPendingBox');
      await box.put('pendingGems', 200);
      await iap.initializeForTest(box);

      // 2つの並行呼び出し
      final futures = [
        iap.consumePendingGems(),
        iap.consumePendingGems(),
      ];
      final results = await Future.wait(futures);

      // 一方が200、もう一方が0（二重消費防止）
      expect(results, contains(200));
      expect(results, contains(0));
      // 合計が200（倍消費されていない）
      expect(results.fold<int>(0, (s, v) => s + v), 200);
    });

    test('初期化なしでもデフォルト値で動作する', () async {
      final fresh = IAPService();
      final result = await fresh.consumePendingGems();
      expect(result, 0);
    });
  });
}
