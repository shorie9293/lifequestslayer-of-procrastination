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
}
