import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

    test('パスコードは salt rpg-app-lock: + sha256 で保存される', () async {
      await repo.setPasscode('1234');
      final expected =
          sha256.convert(utf8.encode('rpg-app-lock:1234')).toString();
      expect(repo.getPasscodeHash(), expected);
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
      expect(repo.getPasscodeHash(),
          sha256.convert(utf8.encode('rpg-app-lock:9876')).toString());
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
