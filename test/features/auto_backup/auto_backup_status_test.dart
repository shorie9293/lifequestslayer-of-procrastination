import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';

void main() {
  group('AutoBackupStatus', () {
    test('初期状態は未試行・未失敗', () {
      final status = AutoBackupStatus.initial;
      expect(status.hasAttempted, isFalse);
      expect(status.hasFailed, isFalse);
      expect(status.isDegraded, isFalse);
      expect(status.lastSuccessAt, isNull);
      expect(status.lastError, isNull);
      expect(status.consecutiveFailures, 0);
    });

    test('成功はカウンタを0へ戻し成功時刻を記録する', () {
      final at = DateTime(2026, 10, 29, 9);
      var status = AutoBackupStatus.initial.recordFailure(
        DateTime(2026, 10, 28, 9),
        StateError('前日失敗'),
      );
      expect(status.consecutiveFailures, 1);

      status = status.recordSuccess(at);
      expect(status.consecutiveFailures, 0);
      expect(status.hasFailed, isFalse);
      expect(status.lastSuccessAt, at);
      expect(status.lastAttemptAt, at);
      expect(status.lastError, isNull);
    });

    test('失敗は成功時刻を保持しカウンタを進める', () {
      final successAt = DateTime(2026, 10, 27, 9);
      final failAt = DateTime(2026, 10, 28, 9);
      final status = AutoBackupStatus.initial
          .recordSuccess(successAt)
          .recordFailure(failAt, StateError('壊れた'));

      expect(status.lastSuccessAt, successAt);
      expect(status.lastAttemptAt, failAt);
      expect(status.consecutiveFailures, 1);
      expect(status.hasFailed, isTrue);
      expect(status.lastError, contains('壊れた'));
    });

    test('連続失敗が閾値で isDegraded になる', () {
      var status = AutoBackupStatus.initial;
      final at = DateTime(2026, 10, 29, 9);
      for (var i = 0; i < AutoBackupStatus.degradedThreshold; i++) {
        expect(status.isDegraded, isFalse);
        status = status.recordFailure(at, StateError('失敗$i'));
      }
      expect(status.consecutiveFailures, AutoBackupStatus.degradedThreshold);
      expect(status.isDegraded, isTrue);
    });

    test('負の連続失敗回数は生成時に拒否する', () {
      expect(
        () => AutoBackupStatus(consecutiveFailures: -1),
        throwsArgumentError,
      );
    });

    test('失敗回数1以上で理由が空なら生成時に拒否する', () {
      expect(
        () => AutoBackupStatus(consecutiveFailures: 1),
        throwsArgumentError,
      );
      expect(
        () => AutoBackupStatus(consecutiveFailures: 1, lastError: ''),
        throwsArgumentError,
      );
    });

    test('JSON 往復で値が保たれる', () {
      final at = DateTime(2026, 10, 29, 9, 30);
      final status = AutoBackupStatus.initial
          .recordSuccess(DateTime(2026, 10, 28, 9))
          .recordFailure(at, ArgumentError('書けない'));

      final restored = AutoBackupStatus.fromJson(status.toJson());
      expect(restored.lastSuccessAt, DateTime(2026, 10, 28, 9));
      expect(restored.lastAttemptAt, at);
      expect(restored.consecutiveFailures, 1);
      expect(restored.lastError, status.lastError);
    });

    test('JSON が欠損・破損なら初期状態へ落とす', () {
      expect(AutoBackupStatus.fromJson({}).hasAttempted, isFalse);
      expect(
        AutoBackupStatus.fromJson({'consecutiveFailures': 'x'})
            .consecutiveFailures,
        0,
      );
      expect(
        AutoBackupStatus.fromJson({
          'consecutiveFailures': 2,
          'lastError': null,
        }).lastError,
        '原因不明の失敗',
      );
    });

    test('summarizeError は1行に畳み、長すぎれば切り詰める', () {
      expect(AutoBackupStatus.summarizeError(StateError('a\nb  c')), 'Bad state: a b c');
      final long = 'x' * 200;
      final summarized = AutoBackupStatus.summarizeError(long);
      expect(summarized.length, lessThanOrEqualTo(121));
      expect(summarized.endsWith('…'), isTrue);
    });
  });

  group('InMemoryAutoBackupStatusStore', () {
    test('未保存なら null、保存後は同じ値を返す', () async {
      final store = InMemoryAutoBackupStatusStore();
      expect(await store.read(), isNull);

      final status = AutoBackupStatus.initial.recordSuccess(
        DateTime(2026, 10, 29, 9),
      );
      await store.write(status);
      final read = await store.read();
      expect(read, isNotNull);
      expect(read!.lastSuccessAt, DateTime(2026, 10, 29, 9));
    });

    test('初期状態を注入できる', () async {
      final injected = AutoBackupStatus.initial.recordFailure(
        DateTime(2026, 10, 29, 9),
        StateError('注入'),
      );
      final store = InMemoryAutoBackupStatusStore(injected);
      expect((await store.read())!.consecutiveFailures, 1);
    });
  });
}
