import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_service.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';

/// 起動時の自動バックアップを投げっぱなしで仕掛ける。
///
/// - 戻り値は void。UI（初回描画）をブロックしない
/// - 例外は debugPrint のみで握る（アプリを壊さない）
/// - 成否は [statusStore] に記録し、画面が「未実行」と「毎回失敗」を
///   区別できるようにする（既定は端末内ファイル）
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  AutoBackupStore? store,
  AutoBackupStatusStore? statusStore,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
}) {
  Future.microtask(() async {
    try {
      final service = AutoBackupService(
        store: store ?? FileAutoBackupStore(),
        policy: policy,
        statusStore: statusStore ?? FileAutoBackupStatusStore(),
      );
      final result = await service.run(buildJson);
      if (result.error != null) {
        appLog.warn('[auto_backup] 失敗: ${result.error}');
      } else {
        appLog.debug(
          '[auto_backup] ran=${result.ran} file=${result.fileName} pruned=${result.pruned}',
        );
      }
    } catch (e) {
      appLog.warn('[auto_backup] 想定外の失敗: $e');
    }
  });
}
