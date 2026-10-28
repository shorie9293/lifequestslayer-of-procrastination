import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';

/// 1回の自動バックアップ実行結果。
class AutoBackupResult {
  final bool ran;
  final String? fileName;
  final List<String> pruned;
  final String? error;

  AutoBackupResult({
    this.ran = false,
    this.fileName,
    List<String>? pruned,
    this.error,
  }) : pruned = pruned ?? const [];

  @override
  String toString() =>
      'AutoBackupResult(ran: $ran, fileName: $fileName, pruned: $pruned, error: $error)';
}

/// 起動時1日1回の自動バックアップを担う。
///
/// 手順: list → 最新時刻判定 → 書込 → 世代ローテーション。
/// いかなる例外も握って [AutoBackupResult.error] に載せ、アプリを壊さない。
class AutoBackupService {
  AutoBackupService({
    required AutoBackupStore store,
    AutoBackupPolicy policy = const AutoBackupPolicy(),
    DateTime Function()? now,
  })  : _store = store,
        _policy = policy,
        _now = now ?? DateTime.now;

  final AutoBackupStore _store;
  final AutoBackupPolicy _policy;
  final DateTime Function() _now;

  Future<AutoBackupResult> run(Future<String> Function() buildJson) async {
    try {
      final entries = await _store.list();
      final lastAt = _policy.latestCreatedAt(entries);
      final current = _now();

      if (!_policy.shouldRun(lastAt: lastAt, now: current)) {
        return AutoBackupResult(ran: false);
      }

      final json = await buildJson();
      final fileName = AutoBackupPolicy.fileNameFor(current);
      await _store.write(fileName, json);

      final pruned = <String>[];
      final after = await _store.list();
      for (final entry in _policy.prune(after)) {
        try {
          await _store.delete(entry.fileName);
          pruned.add(entry.fileName);
        } catch (e) {
          // 1件の削除失敗でバックアップ本体を失わない
          return AutoBackupResult(
            ran: true,
            fileName: fileName,
            pruned: pruned,
            error: 'prune 失敗: ${entry.fileName} ($e)',
          );
        }
      }

      return AutoBackupResult(ran: true, fileName: fileName, pruned: pruned);
    } catch (e) {
      return AutoBackupResult(ran: false, error: e.toString());
    }
  }
}
