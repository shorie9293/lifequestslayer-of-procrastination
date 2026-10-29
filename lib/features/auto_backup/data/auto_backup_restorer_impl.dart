import 'package:flutter/foundation.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_restorer.dart';

/// 自動バックアップ復元の本番アダプタ。
///
/// 手順:
/// 1. [AutoBackupStore.read] で対象を読む
/// 2. [AutoBackupPresenter.canRestore] で検証（不可なら ok:false）
/// 3. **復元前に**現状スナップショットを本日分ファイルへ強制保存（安全網）
/// 4. 現世既存の復元経路 [applyBackup] で適用
///
/// いかなる例外も握って ok:false を返し、画面を壊さない。
class AutoBackupRestorerImpl implements AutoBackupRestorer {
  AutoBackupRestorerImpl({
    required AutoBackupStore store,
    required Future<String> Function() buildCurrentJson,
    required Future<void> Function(String json) applyBackup,
    DateTime Function()? now,
  })  : _store = store,
        _buildCurrentJson = buildCurrentJson,
        _applyBackup = applyBackup,
        _now = now ?? DateTime.now;

  final AutoBackupStore _store;
  final Future<String> Function() _buildCurrentJson;
  final Future<void> Function(String json) _applyBackup;
  final DateTime Function() _now;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    try {
      final json = await _store.read(fileName);
      if (!AutoBackupPresenter.canRestore(json)) {
        return const AutoBackupRestoreResult(
          ok: false,
          message: 'バックアップが壊れているため復元できません',
        );
      }

      // 復元前の現状を必ず退避する（apply が失敗しても現状は残る）。
      final safetyFileName = AutoBackupPolicy.fileNameFor(_now());
      final snapshot = await _buildCurrentJson();
      await _store.write(safetyFileName, snapshot);

      await _applyBackup(json!);

      return AutoBackupRestoreResult(
        ok: true,
        message: '復元しました（復元前のデータは $safetyFileName に保存）',
        safetyFileName: safetyFileName,
      );
    } catch (e) {
      debugPrint('[auto_backup] 復元失敗: $e');
      return AutoBackupRestoreResult(ok: false, message: '復元に失敗しました: $e');
    }
  }
}
