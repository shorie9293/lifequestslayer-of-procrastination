// 敵討伐イベントのデュアルライト試練（契約 v1）。
//
// .json は単一JSON（kozuchi が読み取り後削除）、.jsonl は追記専用の1行1JSON。
// 双方が同一スキーマ・同一呼出で書かれることを検証する。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/crossapp/data/rpg_enemy_defeat_exporter.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rpg_enemy_defeat_dual_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String jsonPath() => '${tempDir.path}/rpg_enemy_defeat_events.json';
  String jsonlPath() => '${tempDir.path}/rpg_enemy_defeat_events.jsonl';

  group('RpgEnemyDefeatExporter デュアルライト', () {
    test('1回の書き出しで .json と .jsonl の両方が生成される', () async {
      final exporter = RpgEnemyDefeatExporter(filePath: jsonPath());

      await exporter.exportEnemyDefeat(
        taskTitle: 'スライム討伐',
        questRank: 'B',
        baseExp: 100,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      expect(await File(jsonPath()).exists(), isTrue);
      expect(await File(jsonlPath()).exists(), isTrue);
    });

    test('2回書き出すと .jsonl は2行・.json は最後の1件だけになる', () async {
      final exporter = RpgEnemyDefeatExporter(filePath: jsonPath());

      await exporter.exportEnemyDefeat(
        taskTitle: '1件目',
        questRank: 'B',
        baseExp: 100,
        timestamp: '2026-08-24T00:00:00.000Z',
      );
      await exporter.exportEnemyDefeat(
        taskTitle: '2件目',
        questRank: 'A',
        baseExp: 300,
        timestamp: '2026-08-24T01:00:00.000Z',
      );

      final lines = (await File(jsonlPath()).readAsString())
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, hasLength(2));

      final latest = jsonDecode(await File(jsonPath()).readAsString())
          as Map<String, dynamic>;
      expect(latest['taskTitle'], '2件目');
      expect(latest['questRank'], 'A');
      expect(latest['baseExp'], 300);
      expect(latest['timestamp'], '2026-08-24T01:00:00.000Z');
    });

    test('.jsonl の各行が jsonDecode 可能でスキーマに一致する', () async {
      final exporter = RpgEnemyDefeatExporter(filePath: jsonPath());

      // 3回書いて、追記が壊れず3行になることを確認
      for (var i = 0; i < 3; i++) {
        await exporter.exportEnemyDefeat(
          taskTitle: '討伐$i',
          questRank: ['s', 'A', 'b'][i],
          baseExp: 10 * (i + 1),
          timestamp: '2026-08-24T0$i:00:00.000Z',
        );
      }

      final raw = await File(jsonlPath()).readAsString();
      expect(raw.contains('\r'), isFalse);
      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines, hasLength(3));

      for (var i = 0; i < lines.length; i++) {
        final decoded = jsonDecode(lines[i]) as Map<String, dynamic>;
        expect(decoded.keys.toList(),
            ['event', 'taskTitle', 'questRank', 'baseExp', 'timestamp']);
        expect(decoded['event'], 'enemy_defeated');
        expect(decoded['taskTitle'], '討伐$i');
        expect(decoded['questRank'], ['S', 'A', 'B'][i]);
        expect(decoded['baseExp'], 10 * (i + 1));
        expect(DateTime.tryParse(decoded['timestamp'] as String), isNotNull);
      }
    });

    test('親ディレクトリ不在でも双方が作成される（ネストパス）', () async {
      final nested =
          '${tempDir.path}/nested/deep/takamagahara_shared/rpg_enemy_defeat_events.json';
      final exporter = RpgEnemyDefeatExporter(filePath: nested);

      await exporter.exportEnemyDefeat(
        taskTitle: '深い階層のクエスト',
        questRank: 'S',
        baseExp: 1000,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      expect(await File(nested).exists(), isTrue);
      expect(
        await File(
                '${tempDir.path}/nested/deep/takamagahara_shared/rpg_enemy_defeat_events.jsonl')
            .exists(),
        isTrue,
      );
    });

    test('書込不能パスでも例外を投げない（best-effort）', () async {
      final blocker = File('${tempDir.path}/blocker');
      await blocker.writeAsString('x');
      final exporter = RpgEnemyDefeatExporter(
        filePath: '${blocker.path}/rpg_enemy_defeat_events.json',
      );

      await expectLater(
        exporter.exportEnemyDefeat(
          taskTitle: '失敗クエスト',
          questRank: 'B',
          baseExp: 10,
          timestamp: '2026-08-24T00:00:00.000Z',
        ),
        completes,
      );
    });

    test('clock 注入で timestamp 未指定時も決定的に書ける', () async {
      final exporter = RpgEnemyDefeatExporter(
        filePath: jsonPath(),
        clock: () => DateTime.utc(2026, 9, 1, 12, 0, 0),
      );

      await exporter.exportEnemyDefeat(
        taskTitle: '時計注入',
        questRank: 'A',
        baseExp: 300,
      );

      final json = jsonDecode(await File(jsonPath()).readAsString())
          as Map<String, dynamic>;
      expect(json['timestamp'], '2026-09-01T12:00:00.000Z');
    });

    test('baseExp 負値は .json / .jsonl 双方で 0 にクランプされる', () async {
      final exporter = RpgEnemyDefeatExporter(filePath: jsonPath());

      await exporter.exportEnemyDefeat(
        taskTitle: '負値',
        questRank: 'B',
        baseExp: -5,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      final json = jsonDecode(await File(jsonPath()).readAsString())
          as Map<String, dynamic>;
      final line = (await File(jsonlPath()).readAsString()).trim();
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      expect(json['baseExp'], 0);
      expect(decoded['baseExp'], 0);
    });
  });
}
