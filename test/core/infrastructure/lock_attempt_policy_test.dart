import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/lock_attempt_policy.dart';

void main() {
  final now = DateTime(2026, 1, 1, 9, 0, 0);

  group('LockAttemptPolicy.lockoutFor', () {
    test('4回まではロックアウトしない', () {
      expect(LockAttemptPolicy.lockoutFor(0), Duration.zero);
      expect(LockAttemptPolicy.lockoutFor(4), Duration.zero);
    });

    test('5回で30秒', () {
      expect(LockAttemptPolicy.lockoutFor(5), const Duration(seconds: 30));
    });

    test('10回で60秒', () {
      expect(LockAttemptPolicy.lockoutFor(10), const Duration(seconds: 60));
    });

    test('15回で120秒（倍々に増える）', () {
      expect(LockAttemptPolicy.lockoutFor(15), const Duration(seconds: 120));
    });

    test('上限は15分で頭打ち', () {
      expect(
        LockAttemptPolicy.lockoutFor(100),
        const Duration(minutes: 15),
      );
      expect(
        LockAttemptPolicy.lockoutFor(1000),
        LockAttemptPolicy.maxLockout,
      );
    });
  });

  group('LockAttemptPolicy.isLockedOut', () {
    test('lockedUntil が null ならロックアウトでない', () {
      expect(LockAttemptPolicy.isLockedOut(null, now), isFalse);
    });

    test('未来ならロックアウト中、過去・同時刻なら解除済み', () {
      expect(
        LockAttemptPolicy.isLockedOut(
          now.add(const Duration(seconds: 1)),
          now,
        ),
        isTrue,
      );
      expect(
        LockAttemptPolicy.isLockedOut(
          now.subtract(const Duration(seconds: 1)),
          now,
        ),
        isFalse,
      );
      expect(LockAttemptPolicy.isLockedOut(now, now), isFalse);
    });
  });

  group('LockAttemptPolicy.remainingSeconds', () {
    test('切り上げる', () {
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.add(const Duration(milliseconds: 1500)),
          now,
        ),
        2,
      );
    });

    test('過去・同時刻は0', () {
      expect(
        LockAttemptPolicy.remainingSeconds(
          now.subtract(const Duration(seconds: 5)),
          now,
        ),
        0,
      );
      expect(LockAttemptPolicy.remainingSeconds(now, now), 0);
    });
  });

  test('lockoutLabel は残り秒数を含む', () {
    expect(
      LockAttemptPolicy.lockoutLabel(30),
      'しばらく待ってから再試行してください（残り30秒）',
    );
  });
}
