import 'package:rpg_todo/core/logging/app_logger.dart';
import 'package:path_provider/path_provider.dart';

import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/account_deletion/data/hive_account_deletion_data_eraser.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';

import 'app_lock_service.dart';
import 'lock_recovery_policy.dart';

/// 回復処理の結果。画面が成否を正直に表示できるよう、副作用ごとに持つ。
class LockRecoveryResult {
  /// 回復（ロック解除）まで到達したか。
  final bool success;

  /// 前提を満たさず何も変更しなかったか（確認語不一致・ロック無効など）。
  final bool rejected;

  /// 書き出したバックアップの場所（未実施・失敗時は null）。
  final String? backupPath;

  /// バックアップ書き出しに失敗したか（ロック解除は継続する）。
  final bool backupFailed;

  /// 端末内データの初期化まで完了したか。
  final bool dataWiped;

  /// 失敗・拒否の理由（成功時は null）。
  final String? reason;

  const LockRecoveryResult({
    required this.success,
    this.rejected = false,
    this.backupPath,
    this.backupFailed = false,
    this.dataWiped = false,
    this.reason,
  });

  /// 前提を満たさず何も変更しなかった。
  const LockRecoveryResult.rejected({required String reason})
      : success = false,
        rejected = true,
        backupPath = null,
        backupFailed = false,
        dataWiped = false,
        reason = reason;

  /// ロック解除まで到達した。
  const LockRecoveryResult.recovered({
    this.backupPath,
    this.backupFailed = false,
    this.dataWiped = false,
  })  : success = true,
        rejected = false,
        reason = null;

  @override
  String toString() => 'LockRecoveryResult(success: $success, '
      'rejected: $rejected, backupPath: $backupPath, '
      'backupFailed: $backupFailed, dataWiped: $dataWiped, reason: $reason)';
}

/// パスコード忘却時の回復処理。
///
/// 順序は「バックアップ書き出し試行 → ロック解除 → データ初期化」に固定する。
/// 初期化が失敗してもロック解除は済んでいるため、ユーザーが詰まらない
/// （fail-safe）。いかなる例外も上位へ投げない。
class LockRecoveryService {
  LockRecoveryService(
    this._appLock, {
    Future<String?> Function()? backupExporter,
    Future<void> Function()? dataEraser,
  })  : _backupExporter = backupExporter,
        _dataEraser = dataEraser;

  /// 本番の組立。既存の自動バックアップ・全データ消去の実装を再利用する。
  factory LockRecoveryService.production(AppLockService appLock) =>
      LockRecoveryService(
        appLock,
        backupExporter: _exportFullBackup,
        dataEraser: const HiveAccountDeletionDataEraser().erase,
      );

  final AppLockService _appLock;
  final Future<String?> Function()? _backupExporter;
  final Future<void> Function()? _dataEraser;

  /// 確認語 [confirmation] を受けて回復を実行する。
  Future<LockRecoveryResult> recover({required String confirmation}) async {
    if (!LockRecoveryPolicy.canRecover(enabled: _appLock.isLocked)) {
      return const LockRecoveryResult.rejected(reason: 'ロックが有効ではありません');
    }
    if (!LockRecoveryPolicy.isConfirmationValid(confirmation)) {
      return const LockRecoveryResult.rejected(reason: '確認の入力が一致しません');
    }

    String? backupPath;
    var backupFailed = false;
    final exporter = _backupExporter;
    if (exporter != null) {
      try {
        backupPath = await exporter();
      } catch (e) {
        backupFailed = true;
        appLog.warn('[lock_recovery] バックアップ失敗', e);
      }
    }

    try {
      await _appLock.disable();
    } catch (e) {
      appLog.warn('[lock_recovery] ロック解除に失敗', e);
      return LockRecoveryResult(
        success: false,
        backupPath: backupPath,
        backupFailed: backupFailed,
        reason: 'ロックの解除に失敗しました',
      );
    }

    var dataWiped = false;
    final eraser = _dataEraser;
    if (eraser != null) {
      try {
        await eraser();
        dataWiped = true;
      } catch (e) {
        appLog.warn('[lock_recovery] データ初期化に失敗', e);
      }
    }

    return LockRecoveryResult.recovered(
      backupPath: backupPath,
      backupFailed: backupFailed,
      dataWiped: dataWiped,
    );
  }
}

/// 本番のバックアップ書き出し。既存の FullBackupService + FileAutoBackupStore。
///
/// プレイヤー未初期化ならバックアップ対象が無いため null を返す（失敗扱いに
/// しない）。
Future<String?> _exportFullBackup() async {
  final player = await getIt<IPlayerRepository>().loadPlayer();
  if (player == null) return null;
  final tasks = await getIt<ITaskRepository>().loadTasks();
  final boxes = await HiveBackupStorage().capture();
  final json = FullBackupService().encode(
    player: player,
    tasks: tasks,
    boxes: boxes,
    exportedAt: DateTime.now(),
  );
  final now = DateTime.now();
  final fileName = AutoBackupPolicy.fileNameFor(now);
  await FileAutoBackupStore().write(fileName, json);
  final base = await getApplicationDocumentsDirectory();
  return '${base.path}/${FileAutoBackupStore.directoryName}/$fileName';
}
