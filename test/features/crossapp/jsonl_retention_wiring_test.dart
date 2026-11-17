import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_reward_service.dart';

const String _kUserId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
const String _kLinked = 'a1b2c3d4';

String _line(
  String id, {
  String userId = _kUserId,
  String eventType = 'book_completed',
}) =>
    jsonEncode({
      'event_id': id,
      'event_type': eventType,
      'timestamp': '2026-06-07T10:30:00Z',
      'user_id': userId,
      'metadata': const {'count': 1},
    });

void main() {
  group('cross-app 報酬サービス — JSONL 剪定の配線', () {
    late Directory tempDir;
    late String tempFilePath;
    late FileCrossAppRewardService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('jsonl_retention_');
      // 行数参照が無いファイル（election）で剪定の実効性を撃つ。
      tempFilePath = '${tempDir.path}/election_reward_events.jsonl';
      Hive.init(tempDir.path);
      service = FileCrossAppRewardService(
        filePath: tempFilePath,
        hiveBoxName: 'cross_app_rewards_retention_test',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<void> seedConsumed(List<String> ids) async {
      final box = await Hive.openBox('cross_app_rewards_retention_test');
      for (final id in ids) {
        await box.put(id, true);
      }
    }

    int lineCount() {
      final file = File(tempFilePath);
      if (!file.existsSync()) return 0;
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return 0;
      return const LineSplitter().convert(content).length;
    }

    test('処理後にファイルが剪定され、解析行数が履歴長に比例しなくなる', () async {
      final consumed = <String>[for (var i = 0; i < 995; i++) 'old-$i'];
      final pending = <String>[for (var i = 0; i < 5; i++) 'new-$i'];
      final lines = <String>[
        for (final id in consumed) _line(id),
        for (final id in pending) _line(id),
      ];
      File(tempFilePath).writeAsStringSync('${lines.join('\n')}\n');
      await seedConsumed(consumed);

      final rewards =
          await service.processPendingEvents(linkedUserId: _kLinked);

      expect(rewards.length, 5, reason: '未処理5件は報酬になる');
      // 今回処理した5件も「処理済み」ゆえ剪定対象＝ファイルは空になる。
      expect(lineCount(), 0, reason: '処理済み1000行は剪定される');

      // 2回目: 冪等（新たな報酬なし）。
      final second =
          await service.processPendingEvents(linkedUserId: _kLinked);
      expect(second, isEmpty);
      expect(lineCount(), 0);
    });

    test('他ユーザーの未処理行は剪定で落とさない', () async {
      final consumed = <String>[for (var i = 0; i < 50; i++) 'old-$i'];
      final lines = <String>[
        for (final id in consumed) _line(id),
        _line('other-user-event',
            userId: 'ffffffff-0000-0000-0000-000000000000'),
      ];
      File(tempFilePath).writeAsStringSync('${lines.join('\n')}\n');
      await seedConsumed(consumed);

      await service.processPendingEvents(linkedUserId: _kLinked);

      expect(lineCount(), 1);
      expect(
        File(tempFilePath).readAsStringSync(),
        contains('other-user-event'),
      );
    });

    test('壊れ行・空行があっても例外を出さず、壊れ行は上限だけ残す', () async {
      final lines = <String>[
        '',
        '{壊れた',
        for (var i = 0; i < 20; i++) '壊れ行$i',
        _line('pending-1'),
      ];
      File(tempFilePath).writeAsStringSync('${lines.join('\n')}\n');

      final rewards =
          await service.processPendingEvents(linkedUserId: _kLinked);

      expect(rewards.length, 1);
      // 未処理1件は今回処理済み＝剪定、壊れ行10（既定上限）だけ残る。
      expect(lineCount(), 10);
    });

    test('捨てる行が無いときはファイルを書き換えない', () async {
      final content = '${_line('pending-only')}\n';
      File(tempFilePath).writeAsStringSync(content);
      final before = File(tempFilePath).readAsStringSync();

      // リンクなし＝走査自体しない（内容不変）。
      await service.processPendingEvents(linkedUserId: null);
      expect(File(tempFilePath).readAsStringSync(), before);
    });

    test('kozuchi が数える book_completed 行は処理済みでも保持する', () async {
      // tsundoku のファイルは kozuchi が book_completed 行を数える。
      final tsundokuPath = '${tempDir.path}/tsundoku_reward_events.jsonl';
      final tsundokuService = FileCrossAppRewardService(
        filePath: tsundokuPath,
        hiveBoxName: 'cross_app_rewards_retention_test',
      );
      final consumed = <String>['book-1', 'book-2', 'streak-1', 'level-1'];
      final lines = <String>[
        _line('book-1'),
        _line('book-2'),
        _line('streak-1', eventType: 'reading_streak'),
        _line('level-1', eventType: 'level_up'),
      ];
      File(tsundokuPath).writeAsStringSync('${lines.join('\n')}\n');
      await seedConsumed(consumed);

      await tsundokuService.processPendingEvents(linkedUserId: _kLinked);

      final remaining = const LineSplitter()
          .convert(File(tsundokuPath).readAsStringSync().trim());
      expect(remaining.length, 2, reason: 'book_completed 2行のみ残る');
      expect(remaining.every((l) => l.contains('book_completed')), isTrue);
    });
  });
}
