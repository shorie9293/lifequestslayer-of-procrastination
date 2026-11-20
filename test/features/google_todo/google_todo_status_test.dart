import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/features/google_todo/data/google_todo_gateway.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';

void main() {
  group('GoogleTodoStatus.describeSync', () {
    test('未連携はそのまま伝える', () {
      expect(GoogleTodoStatus.notLinked.describeSync(DateTime(2026, 11, 20)),
          '未連携');
    });

    test('一度も同期していなければ未同期', () {
      const s = GoogleTodoStatus(linked: true);
      expect(s.describeSync(DateTime(2026, 11, 20)), '未同期');
    });

    test('失敗が残っていれば理由を出す', () {
      const s = GoogleTodoStatus(linked: true, lastError: 'token_refresh_failed');
      expect(
        s.describeSync(DateTime(2026, 11, 20)),
        '未同期（前回の失敗: token_refresh_failed）',
      );
    });

    test('成功時刻からの経過と件数を出す', () {
      final s = GoogleTodoStatus(
        linked: true,
        lastOkAt: DateTime.utc(2026, 11, 20, 1, 0),
        pulled: 2,
        pushed: 1,
      );
      expect(
        s.describeSync(DateTime.utc(2026, 11, 20, 1, 3)),
        '3分前に同期・取得2/送信1',
      );
    });
  });

  group('describeElapsed', () {
    test('1分未満はたった今', () {
      expect(GoogleTodoStatus.describeElapsed(const Duration(seconds: 30)),
          'たった今');
    });

    test('分・時間・日で切り替わる', () {
      expect(GoogleTodoStatus.describeElapsed(const Duration(minutes: 5)), '5分前');
      expect(GoogleTodoStatus.describeElapsed(const Duration(hours: 3)), '3時間前');
      expect(GoogleTodoStatus.describeElapsed(const Duration(days: 2)), '2日前');
    });
  });

  group('GoogleTodoStatus.fromJson', () {
    test('欠損キーでも落ちない', () {
      final s = GoogleTodoStatus.fromJson(const <String, dynamic>{});
      expect(s.linked, isFalse);
      expect(s.pulled, 0);
      expect(s.pushed, 0);
    });

    test('日時はUTC文字列から復元する', () {
      final s = GoogleTodoStatus.fromJson(const <String, dynamic>{
        'linked': true,
        'email': 'horie.shunta@gmail.com',
        'lastOkAt': '2026-11-20T01:00:00.000Z',
        'pulled': 3,
        'pushed': 2,
      });
      expect(s.linked, isTrue);
      expect(s.email, 'horie.shunta@gmail.com');
      expect(s.lastOkAt, DateTime.utc(2026, 11, 20, 1));
      expect(s.pulled, 3);
      expect(s.pushed, 2);
    });
  });

  group('GoogleTodoSyncResult', () {
    test('失敗が無ければok', () {
      const r = GoogleTodoSyncResult(pulled: 1, pushed: 2);
      expect(r.ok, isTrue);
      expect(r.summary, '取得1件・送信2件');
    });

    test('失敗があれば件数を出す', () {
      const r = GoogleTodoSyncResult(
        pulled: 0,
        pushed: 0,
        failures: <String>['update_google: patch 412'],
      );
      expect(r.ok, isFalse);
      expect(r.summary, '一部失敗（1件）');
    });
  });

  group('describeGoogleTodoFailure', () {
    test('コードごとの文言', () {
      expect(describeGoogleTodoFailure(401, null), contains('ログイン'));
      expect(describeGoogleTodoFailure(403, null), contains('未連携'));
      expect(describeGoogleTodoFailure(429, null), contains('しばらく'));
    });

    test('未知コードはサーバー文言を添える', () {
      expect(
        describeGoogleTodoFailure(500, 'internal'),
        contains('internal'),
      );
    });
  });

  group('GoogleTodoList.fromJson', () {
    test('タイトル空は名称未設定', () {
      expect(GoogleTodoList.fromJson(const {'id': 'x', 'title': '  '}).title,
          '名称未設定');
    });
  });
}
