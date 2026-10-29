import 'package:flutter/widgets.dart';

/// 自動バックアップ画面の Key 集約。
class AutoBackupKeys {
  const AutoBackupKeys._();

  static const Key screen = Key('screen_auto_backup');
  static const Key loading = Key('progress_auto_backup');
  static const Key empty = Key('txt_auto_backup_empty');
  static const Key list = Key('list_auto_backup');
  static const Key backupNowButton = Key('btn_auto_backup_now');
  static const Key confirmRestoreButton = Key('btn_auto_backup_restore_confirm');
  static const Key cancelRestoreButton = Key('btn_auto_backup_restore_cancel');
  static const Key confirmDialog = Key('dlg_auto_backup_restore');

  /// 一覧行（[index] は新しい順）。
  static Key row(int index) => Key('tile_auto_backup_$index');

  /// 復元ボタン（[index] は新しい順）。
  static Key restoreButton(int index) => Key('btn_auto_backup_restore_$index');

  /// 共有ボタン（[index] は新しい順）。
  static Key shareButton(int index) => Key('btn_auto_backup_share_$index');

  /// 設定ハブからの導線。
  static const Key entryFromSettings = Key('tile_settings_auto_backup');
}
