/// 自動バックアップの共有抽象。
abstract interface class AutoBackupSharer {
  Future<void> share(String fileName, String json);
}
