// アカウント削除サービスの試練。
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/account_deletion/domain/account_deletion_service.dart';

void main() {
  late int clearCalls;
  late int signOutCalls;
  late List<String> log;

  AccountDeletionService build({
    bool clearThrows = false,
    bool signOutThrows = false,
  }) {
    return AccountDeletionService(
      clearLocalData: () async {
        clearCalls++;
        log.add('clear');
        if (clearThrows) throw StateError('clear failed');
      },
      signOut: () async {
        signOutCalls++;
        log.add('signOut');
        if (signOutThrows) throw StateError('signOut failed');
      },
    );
  }

  setUp(() {
    clearCalls = 0;
    signOutCalls = 0;
    log = <String>[];
  });

  test('未確認（confirmed=false）では clear も signOut も呼ばない', () async {
    final result = await build().execute(confirmed: false);

    expect(clearCalls, 0);
    expect(signOutCalls, 0);
    expect(result.success, isFalse);
    expect(result.message, isNotEmpty);
    expect(result.retryable, isFalse);
  });

  test('成功経路では clear → signOut を各1回、順序は clear が先', () async {
    final result = await build().execute(confirmed: true);

    expect(clearCalls, 1);
    expect(signOutCalls, 1);
    expect(log, <String>['clear', 'signOut']);
    expect(result.success, isTrue);
  });

  test('clearLocalData が throw したら failure かつ signOut は未呼出', () async {
    final result = await build(clearThrows: true).execute(confirmed: true);

    expect(clearCalls, 1);
    expect(signOutCalls, 0);
    expect(result.success, isFalse);
    expect(result.retryable, isTrue);
    expect(result.message, isNotEmpty);
  });

  test('signOut が throw したら success を返さない', () async {
    final result = await build(signOutThrows: true).execute(confirmed: true);

    expect(clearCalls, 1);
    expect(signOutCalls, 1);
    expect(result.success, isFalse);
    expect(result.message, isNotEmpty);
  });

  test('結果型は message と retryable を保持する', () {
    const ok = AccountDeletionResult.success();
    const ng = AccountDeletionResult.failure(message: 'だめ', retryable: false);
    expect(ok.success, isTrue);
    expect(ok.message, '');
    expect(ng.success, isFalse);
    expect(ng.message, 'だめ');
    expect(ng.retryable, isFalse);
  });
}
