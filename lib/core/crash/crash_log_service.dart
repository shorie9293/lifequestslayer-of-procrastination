import 'dart:async';

import 'package:rpg_todo/core/crash/crash_log_entry.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';

/// 未捕捉例外を端末内ログへ投げっぱなしで記録する窓口。
///
/// 記録は絶対に例外を外へ漏らさない（ログの失敗でアプリを落とさない）。
class CrashLogger {
  CrashLogger({
    CrashLogRepository? repository,
    DateTime Function()? now,
  })  : repository = repository ?? FileCrashLogRepository(),
        _now = now ?? DateTime.now;

  final CrashLogRepository repository;
  final DateTime Function() _now;

  /// 例外を1件記録する（await 不要・投げっぱなし）。
  void record(Object error, StackTrace? st, {String kind = 'uncaught'}) {
    final entry = CrashLogEntry.fromError(
      error,
      st,
      timestamp: _now(),
      kind: kind,
    );
    unawaited(_appendSafely(entry));
  }

  Future<void> _appendSafely(CrashLogEntry entry) async {
    try {
      await repository.append(entry);
    } catch (_) {
      // 記録失敗は握りつぶす（二次障害を起こさない）。
    }
  }
}

/// アプリ全体で共有する既定ロガー（保存先はアプリ書類ディレクトリ）。
final CrashLogger crashLogger = CrashLogger();

/// 直近 [limit] 件を新しい順で返す。
List<CrashLogEntry> recent(List<CrashLogEntry> entries, {int limit = 5}) {
  if (limit <= 0) return const <CrashLogEntry>[];
  final start = entries.length > limit ? entries.length - limit : 0;
  return entries.sublist(start).reversed.toList(growable: false);
}

/// 設定画面などに出す1行サマリー。
///
/// 0件なら null。1件以上なら「前回の異常終了 N件（最終 HH:mm）」。
/// 最終発生が [now] と別日なら「（最終 M/d HH:mm）」と日付を添える。
String? summarize(List<CrashLogEntry> entries, {DateTime Function()? now}) {
  if (entries.isEmpty) return null;
  final newest = entries.reduce(
    (a, b) => b.timestamp.isAfter(a.timestamp) ? b : a,
  );
  final at = newest.timestamp.toLocal();
  final reference = (now ?? DateTime.now)().toLocal();
  final sameDay = at.year == reference.year &&
      at.month == reference.month &&
      at.day == reference.day;
  final hhmm = '${_two(at.hour)}:${_two(at.minute)}';
  final stamp = sameDay ? hhmm : '${at.month}/${at.day} $hhmm';
  return '前回の異常終了 ${entries.length}件（最終 $stamp）';
}

String _two(int v) => v.toString().padLeft(2, '0');
