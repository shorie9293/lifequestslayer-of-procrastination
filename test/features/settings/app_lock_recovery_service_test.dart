import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_service.dart';
import 'package:rpg_todo/core/infrastructure/lock_recovery_service.dart';

void main() {
  late InMemoryAppLockRepository repo;
  late AppLockService appLock;

  setUp(() async {
    repo = InMemoryAppLockRepository();
    appLock = AppLockService(repo);
    await appLock.enableWithPasscode('1234');
  });

  test('確認語が不一致なら何も変更しない', () async {
    final beforeHash = repo.getPasscodeHash();
    var backupCalled = false;
    var eraseCalled = false;
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async {
        backupCalled = true;
        return 'backup.json';
      },
      dataEraser: () async {
        eraseCalled = true;
      },
    );

    final result = await service.recover(confirmation: 'ちがう');

    expect(result.success, isFalse);
    expect(result.rejected, isTrue);
    expect(result.reason, isNotNull);
    expect(backupCalled, isFalse);
    expect(eraseCalled, isFalse);
    expect(repo.isEnabled(), isTrue);
    expect(repo.getPasscodeHash(), beforeHash);
  });

  test('成功するとロック無効・パスコード消去・データ初期化', () async {
    var eraseCalled = false;
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async => 'backup.json',
      dataEraser: () async {
        eraseCalled = true;
      },
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.success, isTrue);
    expect(result.rejected, isFalse);
    expect(result.backupPath, 'backup.json');
    expect(result.backupFailed, isFalse);
    expect(result.dataWiped, isTrue);
    expect(eraseCalled, isTrue);
    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
    expect(repo.getMethod(), AppLockMethod.none);
    expect(repo.getFailedAttempts(), 0);
  });

  test('バックアップはロック解除より前に呼ばれる', () async {
    final order = <String>[];
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async {
        order.add('backup:enabled=${repo.isEnabled()}');
        return 'backup.json';
      },
      dataEraser: () async {
        order.add('erase:enabled=${repo.isEnabled()}');
      },
    );

    await service.recover(confirmation: '初期化');

    expect(order, ['backup:enabled=true', 'erase:enabled=false']);
  });

  test('バックアップが例外でも回復は成立する', () async {
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async => throw StateError('disk full'),
      dataEraser: () async {},
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.success, isTrue);
    expect(result.backupFailed, isTrue);
    expect(result.backupPath, isNull);
    expect(result.dataWiped, isTrue);
    expect(repo.isEnabled(), isFalse);
  });

  test('データ初期化が例外でもロック解除は成立する', () async {
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async => 'backup.json',
      dataEraser: () async => throw StateError('erase failed'),
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.success, isTrue);
    expect(result.dataWiped, isFalse);
    expect(result.backupPath, 'backup.json');
    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
  });

  test('ロックが無効なら rejected で何もしない', () async {
    await appLock.disable();
    var backupCalled = false;
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async {
        backupCalled = true;
        return 'backup.json';
      },
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.success, isFalse);
    expect(result.rejected, isTrue);
    expect(backupCalled, isFalse);
  });

  test('書き出し先が無い（null）場合は失敗扱いにしない', () async {
    final service = LockRecoveryService(
      appLock,
      backupExporter: () async => null,
      dataEraser: () async {},
    );

    final result = await service.recover(confirmation: '初期化');

    expect(result.success, isTrue);
    expect(result.backupFailed, isFalse);
    expect(result.backupPath, isNull);
  });
}
