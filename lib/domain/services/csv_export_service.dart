import 'dart:convert';

import 'package:rpg_todo/domain/models/task.dart';

/// クエスト一覧を CSV (RFC 4180) へ変換する純粋サービス。
///
/// - IO は一切行わない（ファイル書き出しは DataExportService が担う）
/// - 戻り値に BOM は含めない。BOM は [csvBytes] / [withUtf8Bom] で一度だけ付与する
/// - 行区切りは `\r\n`
class CsvExportService {
  const CsvExportService();

  /// 固定のヘッダ行（Task に実在するフィールドのみ）。
  static const List<String> headerColumns = [
    'ID',
    'クエスト名',
    '状態',
    'ランク',
    '期限',
    'タグ',
    '完了',
  ];
}

/// ヘッダ行（CRLF なし）。
String get csvHeader => CsvExportService.headerColumns.join(',');

/// タスク一覧を CSV 文字列へ変換する（純粋関数・BOM なし）。
String exportTasksCsv(List<Task> tasks) {
  final buffer = StringBuffer()..write(csvHeader);
  for (final task in tasks) {
    buffer
      ..write('\r\n')
      ..write(_row(task));
  }
  buffer.write('\r\n');
  return buffer.toString();
}

/// CSV 文字列の先頭に UTF-8 BOM (U+FEFF) を1つだけ付ける。
String withUtf8Bom(String csv) => '\uFEFF$csv';

/// BOM 付き UTF-8 バイト列。先頭3バイトは 0xEF, 0xBB, 0xBF。
///
/// `writeAsString` に BOM 文字を含めた文字列を渡すのではなく、このバイト列を
/// `File.writeAsBytes` で書くことで BOM が必ずバイトとして残る。
List<int> csvBytes(String csv) => utf8.encode(withUtf8Bom(csv));

String _row(Task task) {
  final cells = <String>[
    task.id,
    task.title,
    _statusLabel(task.status),
    task.rank.name,
    _date(task.deadline),
    task.tags.join(';'),
    task.isCompleted ? '済' : '',
  ];
  return cells.map(escapeCsvField).join(',');
}

String _statusLabel(TaskStatus status) => switch (status) {
      TaskStatus.inGuild => '寄合所',
      TaskStatus.active => '進行中',
    };

String _date(DateTime? value) {
  if (value == null) return '';
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// RFC 4180 準拠のフィールドエスケープ。
///
/// `,` `"` `\r` `\n` のいずれかを含む場合は `"` で囲み、内側の `"` は `""` にする。
String escapeCsvField(String value) {
  final needsQuote = value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuote) return value;
  return '"${value.replaceAll('"', '""')}"';
}
