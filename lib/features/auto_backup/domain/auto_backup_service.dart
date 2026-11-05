import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';

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
    AutoBackupStatusStore? statusStore,
    DateTime Function()? now,
  })  : _store = store,
        _policy = policy,
        _statusStore = statusStore,
        _now = now ?? DateTime.now;

  final AutoBackupStore _store;
  final AutoBackupPolicy _policy;

  /// 成否（最終成功・連続失敗）の記録先。null なら記録しない（後方互換）。
  final AutoBackupStatusStore? _statusStore;
  final DateTime Function() _now;

  /// 保存済みの状態を読み出す（記録先が無ければ null）。
  Future<AutoBackupStatus?> loadStatus() async {
    final store = _statusStore;
    if (store == null) return null;
    try {
      return await store.read();
    } catch (_) {
      return null;
    }
  }

  /// 状態の更新を1箇所に集約する（記録の失敗は本体を壊さない）。
  Future<void> _record(
    AutoBackupStatus Function(AutoBackupStatus current) update,
  ) async {
    final store = _statusStore;
    if (store == null) return;
    try {
      final current = await store.read() ?? AutoBackupStatus.initial;
      await store.write(update(current));
    } catch (_) {
      // 記録の失敗は握る（バックアップ本体の成否とは別問題）。
    }
  }

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
          await _record((status) => status.recordSuccess(current));
          return AutoBackupResult(
            ran: true,
            fileName: fileName,
            pruned: pruned,
            error: 'prune 失敗: ${entry.fileName} ($e)',
          );
        }
      }

      await _record((status) => status.recordSuccess(current));
      return AutoBackupResult(ran: true, fileName: fileName, pruned: pruned);
    } catch (e) {
      await _record((status) => status.recordFailure(_now(), e));
      return AutoBackupResult(ran: false, error: e.toString());
    }
  }
}
