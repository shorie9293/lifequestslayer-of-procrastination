import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/lock_recovery_policy.dart';

void main() {
  test('確認語が完全一致すれば true', () {
    expect(LockRecoveryPolicy.isConfirmationValid('初期化'), isTrue);
    expect(LockRecoveryPolicy.confirmationPhrase, '初期化');
  });

  test('確認語が違えば false', () {
    expect(LockRecoveryPolicy.isConfirmationValid('初期'), isFalse);
    expect(LockRecoveryPolicy.isConfirmationValid('初期化する'), isFalse);
    expect(LockRecoveryPolicy.isConfirmationValid(''), isFalse);
    expect(LockRecoveryPolicy.isConfirmationValid('shokika'), isFalse);
  });

  test('前後の空白は無視する', () {
    expect(LockRecoveryPolicy.isConfirmationValid('  初期化  '), isTrue);
    expect(LockRecoveryPolicy.isConfirmationValid('\n初期化\t'), isTrue);
  });

  test('回復できるのはロック有効時のみ', () {
    expect(LockRecoveryPolicy.canRecover(enabled: true), isTrue);
    expect(LockRecoveryPolicy.canRecover(enabled: false), isFalse);
  });
}
