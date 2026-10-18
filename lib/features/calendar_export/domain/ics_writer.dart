import 'dart:convert';

import 'calendar_event.dart';

/// iCalendar (.ics) の純粋生成器。状態を持たず、静的メソッドのみ。
///
/// RFC 5545 に沿って CRLF 改行・75オクテット折返し・テキストエスケープを行う。
class IcsWriter {
  IcsWriter._();

  static const String prodId = '-//Takamagahara//Yaoyorozu OS//JA';

  /// RFC 5545 の TEXT エスケープ。
  ///
  /// バックスラッシュを最初に退避しないと、後続の `\;` などが二重化される。
  static String escapeText(String raw) {
    var s = raw.replaceAll('\\', '\\\\');
    s = s.replaceAll(';', '\\;');
    s = s.replaceAll(',', '\\,');
    s = s.replaceAll('\r\n', '\\n');
    s = s.replaceAll('\n', '\\n');
    s = s.replaceAll('\r', '\\n');
    return s;
  }

  /// UTF-8 オクテット基準で 75 オクテット折返し。
  ///
  /// 継続行は先頭に半角スペース 1 個。マルチバイト文字は rune 単位で
  /// 積算するため分断されない。
  static String foldLine(String line) {
    const maxOctets = 75;
    final segments = <String>[];
    final current = StringBuffer();
    var octets = 0;
    var limit = maxOctets;

    for (final rune in line.runes) {
      final ch = String.fromCharCode(rune);
      final len = utf8.encode(ch).length;
      if (octets + len > limit && current.isNotEmpty) {
        segments.add(current.toString());
        current.clear();
        octets = 0;
        // 継続行は先頭スペース 1 オクテットを消費する。
        limit = maxOctets - 1;
      }
      current.write(ch);
      octets += len;
    }
    segments.add(current.toString());
    return segments.join('\r\n ');
  }

  /// 1 イベント分の論理行（折返し前）。
  static List<String> eventLines(CalendarEvent e, {DateTime? generatedAt}) {
    final stamp = _formatUtc(generatedAt ?? DateTime.now());
    return [
      'BEGIN:VEVENT',
      'UID:${e.uid}',
      'DTSTAMP:$stamp',
      'DTSTART;VALUE=DATE:${e.dateStamp}',
      'SUMMARY:${escapeText(e.summary)}',
      if (e.description != null) 'DESCRIPTION:${escapeText(e.description!)}',
      'END:VEVENT',
    ];
  }

  /// カレンダー全体を CRLF のみで書き出す。
  ///
  /// イベントは date 昇順 → uid 昇順で安定ソートする（入力は変更しない）。
  static String write(
    List<CalendarEvent> events, {
    String calendarName = '高天原',
    DateTime? generatedAt,
  }) {
    final sorted = [...events]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.uid.compareTo(b.uid);
      });

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:$prodId',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${escapeText(calendarName)}',
      for (final e in sorted) ...eventLines(e, generatedAt: generatedAt),
      'END:VCALENDAR',
    ];

    final body = lines.map(foldLine).join('\r\n');
    return '$body\r\n';
  }

  static String _formatUtc(DateTime dt) {
    final u = dt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final ymd =
        '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}';
    final hms = '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
    return '${ymd}T$hms';
  }
}
