// アカウント削除（退会）政策の試練。
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/account_deletion/domain/account_deletion_policy.dart';

void main() {
  const policy = AccountDeletionPolicy();

  group('canDelete', () {
    test('セッションが無ければ削除できない', () {
      expect(policy.canDelete(hasActiveSession: false), isFalse);
    });

    test('セッションがあれば削除できる', () {
      expect(policy.canDelete(hasActiveSession: true), isTrue);
    });
  });

  group('isConfirmationSatisfied', () {
    test('完全一致のみ true', () {
      expect(
        policy.isConfirmationSatisfied(
          input: AccountDeletionPolicy.confirmationPhrase,
          expected: AccountDeletionPolicy.confirmationPhrase,
        ),
        isTrue,
      );
      expect(
        policy.isConfirmationSatisfied(input: '削除する', expected: '削除'),
        isFalse,
      );
      expect(
        policy.isConfirmationSatisfied(input: '削', expected: '削除'),
        isFalse,
      );
      expect(
        policy.isConfirmationSatisfied(input: '', expected: '削除'),
        isFalse,
      );
    });

    test('前後の空白は trim される（中間空白は不可）', () {
      expect(
        policy.isConfirmationSatisfied(input: '  削除 \n', expected: '削除'),
        isTrue,
      );
      expect(
        policy.isConfirmationSatisfied(input: '削 除', expected: '削除'),
        isFalse,
      );
    });
  });

  group('summary', () {
    test('削除対象が列挙文に含まれる', () {
      final text = policy.summary(const <String>['冒険者データ', '戦闘記録']);
      expect(text, contains('冒険者データ'));
      expect(text, contains('戦闘記録'));
      expect(text, contains('取り消せません'));
    });

    test('既定ラベルは空でなく、box 名も実在の7種以上を含む', () {
      expect(AccountDeletionPolicy.targetLabels, isNotEmpty);
      expect(
        AccountDeletionPolicy.targetBoxNames,
        containsAll(<String>[
          'playerBox',
          'tasksBox',
          'settingsBox',
          'reminderBox',
          'notification_settings',
          'battle_records',
          'practice_logs',
        ]),
      );
      expect(
        policy.summary(AccountDeletionPolicy.targetLabels),
        contains('冒険者'),
      );
    });

    test('ラベルが空なら削除対象なしと返す', () {
      expect(policy.summary(const <String>[]), contains('削除対象'));
    });
  });
}
