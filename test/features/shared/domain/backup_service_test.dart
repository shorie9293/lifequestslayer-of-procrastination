import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/backup_service.dart';

/// 道標§五#17: データエクスポート＆バックアップ可視化の試練（中核ロジック）。
///
/// BackupService は Hive 永続化の詳細を隠蔽し、以下の純粋ロジックを提供する:
/// 1. buildBackupJson — Player + Task 一覧をバージョン付き JSON エンベロープに直列化
/// 2. parseBackupJson — エンベロープを検証し、復元可能なスナップショットを返す
/// 3. 不正 JSON / 不正バージョンは例外を投げる
void main() {
  group('BackupService.buildBackupJson', () {
    test('Player と Task をバージョン付き JSON に直列化する', () {
      final player = Player().copyWith(coins: 120, gems: 3);
      final tasks = [
        Task(id: 't1', title: '報告書を書く'),
        Task(id: 't2', title: '朝のストレッチ', isCompleted: true),
      ];

      final json = BackupService.buildBackupJson(
        player: player,
        tasks: tasks,
        exportedAt: DateTime(2026, 9, 1, 6, 0),
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['version'], BackupService.currentVersion);
      expect(decoded['exportedAt'], '2026-09-01T06:00:00.000');
      expect(decoded['player']['coins'], 120);
      expect(decoded['player']['gems'], 3);
      final taskList = decoded['tasks'] as List;
      expect(taskList.length, 2);
      expect(taskList[0]['id'], 't1');
      expect(taskList[1]['isCompleted'], isTrue);
    });

    test('Player が null の場合 player フィールドは null になる', () {
      final json = BackupService.buildBackupJson(
        player: null,
        tasks: const [],
        exportedAt: DateTime(2026, 9, 1),
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['player'], isNull);
      expect(decoded['tasks'], isEmpty);
    });

    test('Task が空でも有効なエンベロープを生成する', () {
      final json = BackupService.buildBackupJson(
        player: Player(),
        tasks: const [],
        exportedAt: DateTime(2026, 9, 1),
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['tasks'], isEmpty);
    });
  });

  group('BackupService.parseBackupJson', () {
    test('正しいエンベロープを復元可能なスナップショットに変換する', () {
      final player = Player().copyWith(coins: 500, currentJob: Job.monk);
      final json = BackupService.buildBackupJson(
        player: player,
        tasks: [Task(id: 'a', title: 'タスクA')],
        exportedAt: DateTime(2026, 9, 1, 12, 30),
      );

      final snapshot = BackupService.parseBackupJson(json);

      expect(snapshot.player, isNotNull);
      expect(snapshot.player!.coins, 500);
      expect(snapshot.player!.currentJob, Job.monk);
      expect(snapshot.tasks.length, 1);
      expect(snapshot.tasks.first.title, 'タスクA');
    });

    test('不正な JSON 文字列には FormatException を投げる', () {
      expect(
        () => BackupService.parseBackupJson('not-json{{{'),
        throwsA(isA<FormatException>()),
      );
    });

    test('対応していないバージョンには例外を投げる', () {
      final player = Player();
      final json = BackupService.buildBackupJson(
        player: player,
        tasks: const [],
        exportedAt: DateTime(2026, 9, 1),
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      decoded['version'] = 9999;
      final wrongVersionJson = jsonEncode(decoded);

      expect(
        () => BackupService.parseBackupJson(wrongVersionJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('player フィールドが null の場合は null Player を返す', () {
      final json = BackupService.buildBackupJson(
        player: null,
        tasks: const [],
        exportedAt: DateTime(2026, 9, 1),
      );
      final snapshot = BackupService.parseBackupJson(json);
      expect(snapshot.player, isNull);
      expect(snapshot.tasks, isEmpty);
    });
  });

  group('BackupService.version 整合', () {
    test('currentVersion は 1 以上で定義されている', () {
      expect(BackupService.currentVersion, greaterThanOrEqualTo(1));
    });
  });
}
