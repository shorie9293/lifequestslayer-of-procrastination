import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/crossapp/data/rpg_enemy_defeat_exporter.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rpg_enemy_defeat_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('RpgEnemyDefeatExporter', () {
    test('敵討伐イベントを共有ストレージ形式の単一JSONで書く', () async {
      final filePath = '${tempDir.path}/rpg_enemy_defeat_events.json';
      final exporter = RpgEnemyDefeatExporter(filePath: filePath);

      await exporter.exportEnemyDefeat(
        taskTitle: 'スライム討伐',
        questRank: 'B',
        baseExp: 100,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      final file = File(filePath);
      expect(await file.exists(), isTrue);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(json['event'], 'enemy_defeated');
      expect(json['taskTitle'], 'スライム討伐');
      expect(json['questRank'], 'B');
      expect(json['baseExp'], 100);
      expect(json['timestamp'], '2026-08-24T00:00:00.000Z');
    });

    test('クエストランクは大文字に正規化される', () async {
      final filePath = '${tempDir.path}/rpg_enemy_defeat_events.json';
      final exporter = RpgEnemyDefeatExporter(filePath: filePath);

      await exporter.exportEnemyDefeat(
        taskTitle: '竜討伐',
        questRank: 'b',
        baseExp: 200,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      final json =
          jsonDecode(await File(filePath).readAsString()) as Map<String, dynamic>;
      // kozuchi RpgTaskBonusService が .toUpperCase() で照合するため大文字で書く
      expect(json['questRank'], 'B');
    });

    test('timestamp 未指定時は現在時刻のISO8601で書かれる', () async {
      final filePath = '${tempDir.path}/rpg_enemy_defeat_events.json';
      final exporter = RpgEnemyDefeatExporter(filePath: filePath);

      await exporter.exportEnemyDefeat(
        taskTitle: 'クエスト',
        questRank: 'A',
        baseExp: 50,
      );

      final json =
          jsonDecode(await File(filePath).readAsString()) as Map<String, dynamic>;
      final ts = json['timestamp'] as String;
      expect(DateTime.tryParse(ts), isNotNull);
    });

    test('親ディレクトリが存在しなくても作成される', () async {
      final filePath =
          '${tempDir.path}/nested/deep/takamagahara_shared/rpg_enemy_defeat_events.json';
      final exporter = RpgEnemyDefeatExporter(filePath: filePath);

      await exporter.exportEnemyDefeat(
        taskTitle: '深い階層のクエスト',
        questRank: 'S',
        baseExp: 300,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      expect(await File(filePath).exists(), isTrue);
    });

    test('書き込み失敗時に例外を投げない（best-effort）', () async {
      // 親としてファイルが既に存在するパスを指定 → create(recursive) が失敗する
      final blockerFile = File('${tempDir.path}/blocker');
      await blockerFile.writeAsString('x');
      final exporter = RpgEnemyDefeatExporter(
        filePath: '${blockerFile.path}/rpg_enemy_defeat_events.json',
      );

      // 例外を投げずに完了する
      await exporter.exportEnemyDefeat(
        taskTitle: '失敗クエスト',
        questRank: 'B',
        baseExp: 10,
        timestamp: '2026-08-24T00:00:00.000Z',
      );
    });
  });
}
