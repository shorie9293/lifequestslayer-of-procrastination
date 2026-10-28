import 'package:flutter/foundation.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_service.dart';

/// 起動時の自動バックアップを投げっぱなしで仕掛ける。
///
/// - 戻り値は void。UI（初回描画）をブロックしない
/// - 例外は debugPrint のみで握る（アプリを壊さない）
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  AutoBackupStore? store,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
}) {
  Future.microtask(() async {
    try {
      final service = AutoBackupService(
        store: store ?? FileAutoBackupStore(),
        policy: policy,
      );
      final result = await service.run(buildJson);
      if (result.error != null) {
        debugPrint('[auto_backup] 失敗: ${result.error}');
      } else {
        debugPrint(
          '[auto_backup] ran=${result.ran} file=${result.fileName} pruned=${result.pruned}',
        );
      }
    } catch (e) {
      debugPrint('[auto_backup] 想定外の失敗: $e');
    }
  });
}
