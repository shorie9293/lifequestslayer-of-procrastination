import 'dart:convert';

import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップ一覧の1行分（表示用の派生値）。
class AutoBackupRow {
  const AutoBackupRow({
    required this.entry,
    required this.byteSize,
    required this.generation,
    required this.restorable,
  });

  final AutoBackupEntry entry;
  final int byteSize;

  /// 1始まりの世代番号（1 = 最新）。
  final int generation;

  /// 復元可能な JSON か。
  final bool restorable;

  String get dateLabel => AutoBackupPresenter.formatDate(entry.createdAt);

  String get sizeLabel => AutoBackupPresenter.formatSize(byteSize);

  /// 例: '2026-10-29 07:12 / 12.4 KB / 第1世代'
  String get displayLabel => '$dateLabel / $sizeLabel / 第$generation世代';
}

/// 自動バックアップの表示ロジック（純粋・I/O なし）。
class AutoBackupPresenter {
  const AutoBackupPresenter({this.keep = AutoBackupPolicy.defaultKeep});

  final int keep;

  /// ローカル暦の `yyyy-MM-dd HH:mm`。UTC 変換しない。
  static String formatDate(DateTime at) {
    final month = at.month.toString().padLeft(2, '0');
    final day = at.day.toString().padLeft(2, '0');
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return '${at.year}-$month-$day $hour:$minute';
  }

  /// 1024 基数。1024 未満は B、1MB 未満は KB、以上は MB（小数1桁）。
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 復元可能な JSON か。絶対に例外を投げない。
  static bool canRestore(String? json) {
    if (json == null || json.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(json);
      return decoded is Map;
    } catch (_) {
      return false;
    }
  }

  /// createdAt 降順 → fileName 降順。元リストは破壊しない。
  static List<AutoBackupEntry> sortNewestFirst(List<AutoBackupEntry> entries) {
    final sorted = List<AutoBackupEntry>.of(entries);
    sorted.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.fileName.compareTo(a.fileName);
    });
    return sorted;
  }

  /// 例: '保持 3世代中 2件'
  String retentionLabel(int count) => '保持 $keep世代中 $count件';

  /// 自動バックアップのみを新しい順に整形する。
  ///
  /// [contents] は fileName → 本文。null はサイズ0・復元不可。
  List<AutoBackupRow> buildRows({
    required List<AutoBackupEntry> entries,
    required Map<String, String?> contents,
  }) {
    final auto = sortNewestFirst(
      entries
          .where((e) => AutoBackupPolicy.isAutoBackupFile(e.fileName))
          .toList(growable: false),
    );
    final rows = <AutoBackupRow>[];
    for (var i = 0; i < auto.length; i++) {
      final entry = auto[i];
      final content = contents[entry.fileName];
      rows.add(
        AutoBackupRow(
          entry: entry,
          byteSize: content == null ? 0 : utf8.encode(content).length,
          generation: i + 1,
          restorable: canRestore(content),
        ),
      );
    }
    return rows;
  }
}
