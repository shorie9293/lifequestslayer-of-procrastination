import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';

void main() {
  group('InMemoryAppLockRepository', () {
    late InMemoryAppLockRepository repo;

    setUp(() {
      repo = InMemoryAppLockRepository();
    });

    test('初期状態: 無効・方式none・ハッシュnull', () {
      expect(repo.isEnabled(), isFalse);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.verifyPasscode('0000'), isFalse);
    });

    test('パスコードは v2 形式（反復ハッシュ + ランダムsalt）で保存される', () async {
      await repo.setPasscode('1234');
      expect(
        repo.getPasscodeHash(),
        matches(RegExp(r'^v2:1200:[0-9a-f]{32}:[0-9a-f]{64}$')),
      );
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('1235'), isFalse);
    });

    test('clearPasscode で照合が必ず失敗する', () async {
      await repo.setPasscode('1234');
      await repo.clearPasscode();
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.verifyPasscode('1234'), isFalse);
    });

    test('enabled / method の保存 往復', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.passcode);
      expect(repo.isEnabled(), isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);
      await repo.setMethod(AppLockMethod.biometric);
      expect(repo.getMethod(), AppLockMethod.biometric);
    });
  });

  group('HiveAppLockRepository（単一box zone）', () {
    late HiveAppLockRepository repo;

    setUpAll(() async {
      // Hive未初期化zone汚染を避けるためテスト内で初期化する
      final dir =
          await Directory.systemTemp.createTemp('app_lock_hive_test');
      Hive.init(dir.path);
    });

    setUp(() async {
      repo = HiveAppLockRepository();
      if (Hive.isBoxOpen('settingsBox')) {
        await Hive.box('settingsBox').clear();
      }
    });

    test('パスコード往復・照合', () async {
      await repo.setPasscode('9876');
      expect(repo.verifyPasscode('9876'), isTrue);
      expect(repo.verifyPasscode('9875'), isFalse);
      expect(
        repo.getPasscodeHash(),
        matches(RegExp(r'^v2:1200:[0-9a-f]{32}:[0-9a-f]{64}$')),
      );
    });

    test('試行回数・ロックアウト・猶予の往復', () async {
      final until = DateTime(2026, 1, 1, 9, 0, 30);
      await repo.setRelockGraceSeconds(60);
      await repo.setFailedAttempts(7);
      await repo.setLockedUntil(until);
      expect(repo.getRelockGraceSeconds(), 60);
      expect(repo.getFailedAttempts(), 7);
      expect(repo.getLockedUntil(), until);

      await repo.resetAttempts();
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
      expect(repo.getRelockGraceSeconds(), 60);
    });

    test('enabled / method 往復', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.passcode);
      expect(repo.isEnabled(), isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);
    });

    test('clearPasscode', () async {
      await repo.setPasscode('1111');
      await repo.clearPasscode();
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.verifyPasscode('1111'), isFalse);
    });
  });
}
