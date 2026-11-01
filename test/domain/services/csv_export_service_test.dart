// クエストCSV書き出しの試練（純粋サービス + BOM バイト列）。
//
// - exportTasksCsv は IO を持たない純粋関数（戻り値に BOM を含めない）
// - BOM は csvBytes / withUtf8Bom の層で一度だけ付与する

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/csv_export_service.dart';

void main() {
  const header = 'ID,クエスト名,状態,ランク,期限,タグ,完了';

  Task task({
    String id = 't1',
    String title = '魔物討伐',
    TaskStatus status = TaskStatus.inGuild,
    QuestRank rank = QuestRank.B,
    DateTime? deadline,
    List<String> tags = const [],
    bool isCompleted = false,
  }) =>
      Task(
        id: id,
        title: title,
        status: status,
        rank: rank,
        deadline: deadline,
        tags: List<String>.from(tags),
        isCompleted: isCompleted,
      );

  group('exportTasksCsv — ヘッダと行構造', () {
    test('ヘッダ行が期待通り（日本語・CRLF 終端）', () {
      final csv = exportTasksCsv([task()]);
      expect(csv.split('\r\n').first, header);
    });

    test('1件のタスクが1行になり、全フィールドが並ぶ', () {
      final csv = exportTasksCsv([
        task(
          id: 'abc',
          title: '薬草集め',
          status: TaskStatus.active,
          rank: QuestRank.S,
          deadline: DateTime(2026, 3, 4),
          tags: const ['日常', '森'],
          isCompleted: true,
        ),
      ]);
      final rows = csv.split('\r\n');
      expect(rows.length, 3); // header + 1 row + 末尾空文字
      expect(rows[1], 'abc,薬草集め,進行中,S,2026-03-04,日常;森,済');
    });

    test('期限・タグ・完了が未設定なら空セルになる', () {
      final csv = exportTasksCsv([task(id: 'x', title: '素振り')]);
      final rows = csv.split('\r\n');
      expect(rows[1], 'x,素振り,寄合所,B,,,');
    });

    test('空リストでも例外を投げずヘッダのみ返す', () {
      final csv = exportTasksCsv(const []);
      expect(csv, '$header\r\n');
    });
  });

  group('exportTasksCsv — RFC4180 エスケープ', () {
    test('カンマとダブルクォートを含むクエスト名が正しくエスケープされる', () {
      final csv = exportTasksCsv([task(id: 'q1', title: 'a,"b"')]);
      final rows = csv.split('\r\n');
      expect(rows[1], 'q1,"a,""b""",寄合所,B,,,');
      expect(rows[1], contains('"a,""b"""'));
    });

    test('改行を含む値はダブルクォートで囲まれる', () {
      final csv = exportTasksCsv([task(id: 'q2', title: '前段\n後段')]);
      expect(csv, contains('"前段\n後段"'));
    });

    test('カンマを含むタグはセル全体が引用される', () {
      final csv = exportTasksCsv([
        task(id: 'q3', title: 'ok', tags: const ['a,b', 'c']),
      ]);
      final rows = csv.split('\r\n');
      expect(rows[1], 'q3,ok,寄合所,B,,"a,b;c",');
    });
  });

  group('BOM はファイル化層で一度だけ付く', () {
    test('exportTasksCsv の戻り値に U+FEFF が含まれない', () {
      final csv = exportTasksCsv([task(title: 'あいう')]);
      expect(csv.contains('\uFEFF'), isFalse);
      expect(csv.codeUnitAt(0), isNot(0xFEFF));
    });

    test('withUtf8Bom は先頭に1つだけ U+FEFF を付ける', () {
      final bommed = withUtf8Bom('あ');
      expect(bommed.codeUnitAt(0), 0xFEFF);
      expect('\uFEFF'.allMatches(bommed).length, 1);
    });

    test('csvBytes の先頭3要素が EF BB BF、残りは元の CSV に戻る', () {
      final csv = exportTasksCsv([task(title: '薬草集め')]);
      final bytes = csvBytes(csv);

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), csv);
    });

    test('日本語1文字は UTF-8 で3バイトになる（BOM 込みで 3+3*n）', () {
      const csv = 'あ';
      expect(utf8.encode(csv).length, 3);
      expect(csvBytes(csv).length, 3 + 3);
    });

    test('空 CSV でも BOM のみの3バイト列を返す', () {
      expect(csvBytes(''), [0xEF, 0xBB, 0xBF]);
    });

    test('writeAsBytes(csvBytes(...)) で実ファイル先頭に BOM が残る', () async {
      final dir = await Directory.systemTemp.createTemp('rpg_csv_test_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/rpg_quests_20261101.csv');
      final csv = exportTasksCsv([task(title: '薬草集め')]);

      await file.writeAsBytes(csvBytes(csv), flush: true);
      final onDisk = await file.readAsBytes();

      expect(onDisk.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(onDisk.sublist(3)), csv);
    });
  });
}
