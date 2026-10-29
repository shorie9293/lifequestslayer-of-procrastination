/// 自動バックアップの復元結果。
class AutoBackupRestoreResult {
  const AutoBackupRestoreResult({
    required this.ok,
    this.message,
    this.safetyFileName,
  });

  final bool ok;
  final String? message;

  /// 復元前に強制保存した現状スナップショットのファイル名。
  final String? safetyFileName;
}

/// 自動バックアップの復元抽象。
abstract interface class AutoBackupRestorer {
  Future<AutoBackupRestoreResult> restore(String fileName);
}
