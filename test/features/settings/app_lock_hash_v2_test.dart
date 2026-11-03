import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';

String legacyHash(String passcode) =>
    sha256.convert(utf8.encode('rpg-app-lock:$passcode')).toString();

void main() {
  final v2Pattern = RegExp(r'^v2:(\d+):([0-9a-f]{32}):([0-9a-f]{64})$');

  group('v2 ハッシュ（端末ごとランダムsalt + 反復）', () {
    test('同一パスコードでも2インスタンスで保存値が異なる（saltランダム）', () async {
      final a = InMemoryAppLockRepository();
      final b = InMemoryAppLockRepository();
      await a.setPasscode('1234');
      await b.setPasscode('1234');

      expect(a.getPasscodeHash(), isNot(b.getPasscodeHash()));
      expect(a.getPasscodeHash(), matches(v2Pattern));
      expect(b.getPasscodeHash(), matches(v2Pattern));
      expect(a.verifyPasscode('1234'), isTrue);
      expect(b.verifyPasscode('1234'), isTrue);
      expect(a.verifyPasscode('1235'), isFalse);
    });

    test('保存値の iterations は 1200 固定', () async {
      final repo = InMemoryAppLockRepository();
      await repo.setPasscode('9876');
      final parts = repo.getPasscodeHash()!.split(':');
      expect(parts[0], 'v2');
      expect(parts[1], '1200');
    });

    test('旧形式ハッシュは照合でき、照合後に v2 へ移行する', () async {
      final repo = InMemoryAppLockRepository();
      repo.debugSetPasscodeHash(legacyHash('1234'));
      expect(repo.getPasscodeHash(), legacyHash('1234'));

      expect(repo.verifyPasscode('9999'), isFalse);
      expect(repo.getPasscodeHash(), legacyHash('1234'),
          reason: '不一致時に移行してはならない');

      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.getPasscodeHash(), startsWith('v2:'));
      expect(repo.getPasscodeHash(), isNot(legacyHash('1234')));
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('1235'), isFalse);
    });
  });

  group('試行・ロックアウト・猶予の永続化往復', () {
    test('failedAttempts / lockedUntil / grace の往復', () async {
      final repo = InMemoryAppLockRepository();
      expect(repo.getRelockGraceSeconds(), 0);
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);

      final until = DateTime(2026, 1, 1, 9, 0, 30);
      await repo.setRelockGraceSeconds(300);
      await repo.setFailedAttempts(5);
      await repo.setLockedUntil(until);
      expect(repo.getRelockGraceSeconds(), 300);
      expect(repo.getFailedAttempts(), 5);
      expect(repo.getLockedUntil(), until);

      await repo.resetAttempts();
      expect(repo.getRelockGraceSeconds(), 300, reason: 'resetAttempts は猶予を触らない');
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });

    test('負の値は ArgumentError', () async {
      final repo = InMemoryAppLockRepository();
      expect(() => repo.setRelockGraceSeconds(-1), throwsArgumentError);
      expect(() => repo.setFailedAttempts(-1), throwsArgumentError);
    });
  });
}
