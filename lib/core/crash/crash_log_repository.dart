import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rpg_todo/core/crash/crash_log_entry.dart';

/// 端末内クラッシュログの保持上限（超過分は古い行から落とす）。
const int kCrashLogMaxEntries = 50;

/// クラッシュログの保存先抽象（テストで差し替え可能）。
abstract class CrashLogRepository {
  /// 保存済みエントリを古い順で返す。
  Future<List<CrashLogEntry>> loadAll();

  /// 1件追記する。上限超過時は古い行から落とす。
  Future<void> append(CrashLogEntry entry);

  /// 全消去する。
  Future<void> clear();
}

/// 追記内容をローテートした新しいリストにする（共通規則）。
@visibleForTesting
List<CrashLogEntry> rotateCrashLog(
  List<CrashLogEntry> entries,
  CrashLogEntry entry,
) {
  final next = List<CrashLogEntry>.of(entries)..add(entry);
  if (next.length <= kCrashLogMaxEntries) return next;
  return next.sublist(next.length - kCrashLogMaxEntries);
}

/// アプリ書類ディレクトリ配下 `crash_log.jsonl` に1行1JSONで保存する実装。
///
/// - 読み込み時に壊れた行は読み飛ばす。
/// - 書き込みは全件書き直し（最大50件なので十分軽い）。
/// - 入出力の失敗は握って捨てる（クラッシュ記録がアプリを落としてはならない）。
class FileCrashLogRepository implements CrashLogRepository {
  FileCrashLogRepository({
    Future<Directory> Function()? directoryProvider,
    this.fileName = 'crash_log.jsonl',
  }) : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;
  final String fileName;

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<List<CrashLogEntry>> loadAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const <CrashLogEntry>[];
      final raw = await file.readAsString();
      final entries = <CrashLogEntry>[];
      for (final line in const LineSplitter().convert(raw)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parsed = _decodeLine(trimmed);
        if (parsed != null) entries.add(parsed);
      }
      if (entries.length > kCrashLogMaxEntries) {
        return entries.sublist(entries.length - kCrashLogMaxEntries);
      }
      return entries;
    } catch (_) {
      // 保存先が無い（テスト環境等）・読み取り失敗は空扱い。
      return const <CrashLogEntry>[];
    }
  }

  static CrashLogEntry? _decodeLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return null;
      return CrashLogEntry.tryParse(decoded);
    } catch (_) {
      return null; // 壊れた行は読み飛ばす
    }
  }

  @override
  Future<void> append(CrashLogEntry entry) async {
    try {
      final rotated = rotateCrashLog(await loadAll(), entry);
      final file = await _file();
      await file.parent.create(recursive: true);
      final buffer = StringBuffer();
      for (final e in rotated) {
        buffer.writeln(jsonEncode(e.toJson()));
      }
      await file.writeAsString(buffer.toString(), flush: true);
    } catch (_) {
      // 記録できなくてもアプリは落とさない。
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 消せなくても致命的ではない。
    }
  }
}

/// 試練用のメモリ内実装（ローテート規則は本実装と同一）。
class InMemoryCrashLogRepository implements CrashLogRepository {
  InMemoryCrashLogRepository([List<CrashLogEntry>? initial])
      : _entries = List<CrashLogEntry>.of(initial ?? const <CrashLogEntry>[]);

  final List<CrashLogEntry> _entries;

  @override
  Future<List<CrashLogEntry>> loadAll() async =>
      List<CrashLogEntry>.unmodifiable(_entries);

  @override
  Future<void> append(CrashLogEntry entry) async {
    final rotated = rotateCrashLog(_entries, entry);
    _entries
      ..clear()
      ..addAll(rotated);
  }

  @override
  Future<void> clear() async => _entries.clear();
}
