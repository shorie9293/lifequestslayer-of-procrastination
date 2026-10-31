import 'package:flutter/widgets.dart';

/// アカウント削除（退会）導線の試練用 Key 集約。
///
/// 既存の AppKeys は肥大化を避けるため触らず、本 feature 内で一元管理する。
class AccountDeletionAppKeys {
  AccountDeletionAppKeys._();

  /// 設定ハブのタイル。
  static const Key entryFromSettings = Key('tile_settings_account_deletion');

  /// アカウント削除画面。
  static const Key screen = Key('screen_account_deletion');

  /// 確認ダイアログの入力欄。
  static const Key confirmField = Key('field_account_deletion_confirm');

  /// 確認ダイアログの「削除する」。
  static const Key confirmButton = Key('btn_account_deletion_confirm');

  /// 確認ダイアログの「やめる」。
  static const Key cancelButton = Key('btn_account_deletion_cancel');

  /// 画面本体の「削除する」（確認ダイアログを開く）。
  static const Key deleteButton = Key('btn_account_deletion_delete');

  /// 成功文言。
  static const Key successMessage = Key('txt_account_deletion_success');

  /// エラー文言。
  static const Key errorMessage = Key('txt_account_deletion_error');
}
