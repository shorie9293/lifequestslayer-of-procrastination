import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_service.dart';

void main() {
  late InMemoryAppLockRepository repo;
  late AppLockService service;

  setUp(() {
    repo = InMemoryAppLockRepository();
    service = AppLockService(repo);
  });

  group('AppLockService 純ロジック', () {
    test('初期状態はロックされていない', () {
      expect(service.isLocked, isFalse);
    });

    test('無効時は unlock が常に true', () async {
      expect(await service.unlock(), isTrue);
      expect(await service.unlock(passcode: '0000'), isTrue);
      expect(await service.unlock(passcode: '9999'), isTrue);
    });

    test('有効化は4桁の数字のみ許容する', () async {
      await service.enableWithPasscode('1234');
      expect(service.isLocked, isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);
      expect(repo.getPasscodeHash(), isNotNull);
    });

    test('3桁・5桁・非数字は ArgumentError', () async {
      expect(() => service.enableWithPasscode('123'), throwsArgumentError);
      expect(() => service.enableWithPasscode('12345'), throwsArgumentError);
      expect(() => service.enableWithPasscode('12a4'), throwsArgumentError);
      expect(() => service.enableWithPasscode('１２３４'), throwsArgumentError);
      expect(service.isLocked, isFalse);
    });

    test('正しいパスコードで解除、誤コードでは解除されない', () async {
      await service.enableWithPasscode('1234');
      expect(await service.unlock(passcode: '9999'), isFalse);
      expect(service.isLocked, isTrue);
      expect(await service.unlock(passcode: '1234'), isTrue);
    });

    test('パスコードはハッシュ化され平文では保存されない', () async {
      await service.enableWithPasscode('1234');
      expect(repo.getPasscodeHash(), isNot('1234'));
    });

    test('無効化するとロック・ハッシュ・方式が初期化される', () async {
      await service.enableWithPasscode('1234');
      await service.disable();
      expect(service.isLocked, isFalse);
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(await service.unlock(passcode: '1234'), isTrue);
    });

    test('生体認証方式は委譲結果で判定する', () async {
      await repo.setMethod(AppLockMethod.biometric);
      await repo.setEnabled(true);
      expect(await service.unlock(biometricSucceeded: false), isFalse);
      expect(await service.unlock(biometricSucceeded: true), isTrue);
    });
  });

  group('AppLockService ロックアウト', () {
    late DateTime now;
    late AppLockService timed;

    setUp(() async {
      now = DateTime(2026, 1, 1, 9, 0, 0);
      repo = InMemoryAppLockRepository();
      timed = AppLockService(repo, now: () => now);
      await timed.enableWithPasscode('1234');
    });

    test('5回失敗で30秒ロックアウトし、正コードでも照合しない', () async {
      for (var i = 0; i < 5; i++) {
        expect(await timed.unlock(passcode: '0000'), isFalse);
      }
      expect(repo.getFailedAttempts(), 5);
      expect(timed.isLockedOut, isTrue);
      expect(timed.lockoutRemainingSeconds, 30);
      expect(repo.getLockedUntil(), now.add(const Duration(seconds: 30)));

      // ロックアウト中は正コードでも解除されない
      expect(await timed.unlock(passcode: '1234'), isFalse);
      expect(repo.getFailedAttempts(), 5);

      // 30秒後に解除できる
      now = now.add(const Duration(seconds: 31));
      expect(timed.isLockedOut, isFalse);
      expect(await timed.unlock(passcode: '1234'), isTrue);
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });

    test('成功すると失敗回数がリセットされる', () async {
      await timed.unlock(passcode: '0000');
      await timed.unlock(passcode: '0000');
      expect(repo.getFailedAttempts(), 2);
      expect(await timed.unlock(passcode: '1234'), isTrue);
      expect(repo.getFailedAttempts(), 0);
      expect(timed.isLockedOut, isFalse);
    });

    test('猶予の既定は0で、設定が往復する', () async {
      expect(timed.relockGrace, Duration.zero);
      await timed.setRelockGrace(const Duration(minutes: 5));
      expect(timed.relockGrace, const Duration(minutes: 5));
      expect(() => timed.setRelockGrace(const Duration(seconds: -1)),
          throwsArgumentError);
    });
  });
}
