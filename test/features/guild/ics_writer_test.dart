// iCalendar (.ics) 書き出しの純粋ロジック試練。
//
// - escapeText: バックスラッシュを最初に退避し ; , 改行を正しくエスケープ
// - foldLine: 75オクテット折返し・継続行は半角スペース・マルチバイト非分断
// - write: CRLF のみ・VCALENDAR 骨格・date→uid の安定ソート・入力非破壊

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/calendar_export/domain/calendar_event.dart';
import 'package:rpg_todo/features/calendar_export/domain/ics_writer.dart';

int _octets(String s) => utf8.encode(s).length;

/// 折返しを解除して元の論理行へ戻す。
String _unfold(String folded) => folded
    .split('\r\n')
    .map((line) => line.startsWith(' ') ? line.substring(1) : line)
    .join();

void main() {
  group('CalendarEvent', () {
    test('dateStamp は YYYYMMDD のゼロ埋め', () {
      final e = CalendarEvent(
        uid: 'u1',
        date: DateTime(2026, 1, 5),
        summary: 's',
      );
      expect(e.dateStamp, '20260105');
    });
  });

  group('IcsWriter.escapeText', () {
    test('バックスラッシュを最初に退避し、; , 改行をエスケープする', () {
      const raw = 'title; with, comma\\ and\nnewline';
      expect(
        IcsWriter.escapeText(raw),
        'title\\; with\\, comma\\\\ and\\nnewline',
      );
    });

    test('CRLF / CR 単独も \\n に正規化する', () {
      expect(IcsWriter.escapeText('a\r\nb'), 'a\\nb');
      expect(IcsWriter.escapeText('a\rb'), 'a\\nb');
    });

    test('エスケープ済みのバックスラッシュが二重化される（置換順序）', () {
      expect(IcsWriter.escapeText('\\;'), '\\\\\\;');
    });
  });

  group('IcsWriter.foldLine', () {
    test('長いASCII行は全行75オクテット以下・継続行は半角スペース始まり', () {
      final line = 'A' * 300;
      final folded = IcsWriter.foldLine(line);
      final lines = folded.split('\r\n');
      expect(lines.length, greaterThan(1));
      for (final l in lines) {
        expect(_octets(l), lessThanOrEqualTo(75));
      }
      for (final l in lines.skip(1)) {
        expect(l.startsWith(' '), isTrue);
      }
      expect(_unfold(folded), line);
    });

    test('日本語200文字でもマルチバイトを分断せず、全行75オクテット以下', () {
      final line = 'あ' * 200;
      final folded = IcsWriter.foldLine(line);
      final lines = folded.split('\r\n');
      for (final l in lines) {
        expect(_octets(l), lessThanOrEqualTo(75));
        expect(l.contains('\uFFFD'), isFalse);
      }
      expect(_unfold(folded), line);
    });

    test('短い行はそのまま', () {
      expect(IcsWriter.foldLine('SUMMARY:短い'), 'SUMMARY:短い');
    });
  });

  group('IcsWriter.write', () {
    CalendarEvent ev(String uid, DateTime date, String summary,
            {String? description}) =>
        CalendarEvent(
          uid: uid,
          date: date,
          summary: summary,
          description: description,
        );

    test('CRLF のみで改行される（裸の \\n / \\r が無い）', () {
      final ics = IcsWriter.write([
        ev('task-1@takamagahara', DateTime(2026, 1, 5), '討伐'),
      ]);
      expect(ics.contains('\r\n'), isTrue);
      expect(ics.endsWith('\r\n'), isTrue);
      for (final line in ics.split('\r\n')) {
        expect(line.contains('\n'), isFalse);
        expect(line.contains('\r'), isFalse);
      }
    });

    test('VCALENDAR 骨格・PRODID・DTSTART;VALUE=DATE 8桁・UID を持つ', () {
      final ics = IcsWriter.write([
        ev('task-1@takamagahara', DateTime(2026, 1, 5), '討伐'),
      ]);
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('PRODID:${IcsWriter.prodId}'));
      expect(ics, contains('CALSCALE:GREGORIAN'));
      expect(ics, contains('END:VCALENDAR'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('END:VEVENT'));
      expect(ics, contains('UID:task-1@takamagahara'));
      expect(RegExp(r'DTSTART;VALUE=DATE:\d{8}').hasMatch(ics), isTrue);
      expect(ics, contains('DTSTART;VALUE=DATE:20260105'));
      expect(RegExp(r'DTSTAMP:\d{8}T\d{6}Z').hasMatch(ics), isTrue);
    });

    test('date 昇順 → uid 昇順で安定ソートされ、入力リストは破壊されない', () {
      final b = ev('b@x', DateTime(2026, 3, 1), 'B');
      final a2 = ev('a@x', DateTime(2026, 1, 1), 'A2');
      final a1 = ev('a1@x', DateTime(2026, 1, 1), 'A1');
      final input = [b, a2, a1];
      final ics = IcsWriter.write(input);

      final uids =
          RegExp(r'UID:(.+)').allMatches(ics).map((m) => m.group(1)).toList();
      expect(uids, ['a1@x', 'a@x', 'b@x']);
      expect(input.map((e) => e.uid).toList(), ['b@x', 'a@x', 'a1@x']);
    });

    test('description 省略時は DESCRIPTION 行が出ない', () {
      final ics = IcsWriter.write([
        ev('task-1@takamagahara', DateTime(2026, 1, 5), '討伐'),
      ]);
      expect(ics.contains('DESCRIPTION'), isFalse);
    });

    test('description があればエスケープして出力される', () {
      final ics = IcsWriter.write([
        ev('task-1@takamagahara', DateTime(2026, 1, 5), '討伐',
            description: 'ランク A, 見積 30分'),
      ]);
      expect(ics, contains('DESCRIPTION:ランク A\\, 見積 30分'));
    });

    test('CALNAME は escapeText を通す', () {
      final ics = IcsWriter.write(const [], calendarName: '高天原, 暦');
      expect(ics, contains('X-WR-CALNAME:高天原\\, 暦'));
    });
  });
}
