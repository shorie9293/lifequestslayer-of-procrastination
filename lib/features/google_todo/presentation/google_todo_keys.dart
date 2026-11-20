import 'package:flutter/widgets.dart';

/// Google ToDo 連携画面の試練用 Key（寄合所 AppKeys とは分離）。
class GoogleTodoKeys {
  GoogleTodoKeys._();

  static const Key screen = Key('screen_google_todo');
  static const Key loading = Key('progress_google_todo');
  static const Key errorState = Key('txt_google_todo_error');
  static const Key retryButton = Key('btn_google_todo_retry');
  static const Key retryInlineButton = Key('btn_google_todo_retry_inline');

  static const Key notLinkedExplain = Key('txt_google_todo_not_linked');
  static const Key linkButton = Key('btn_google_todo_link');

  static const Key accountLabel = Key('txt_google_todo_account');
  static const Key listLabel = Key('txt_google_todo_list');
  static const Key changeListButton = Key('btn_google_todo_change_list');
  static const Key syncStateLabel = Key('txt_google_todo_sync_state');
  static const Key syncButton = Key('btn_google_todo_sync');
  static const Key unlinkButton = Key('btn_google_todo_unlink');
  static const Key ruleExplain = Key('txt_google_todo_rule');

  static const Key listPicker = Key('dialog_google_todo_lists');
  static const Key unlinkConfirm = Key('dialog_google_todo_unlink_confirm');

  static Key listOption(String id) => Key('row_google_todo_list_$id');

  /// 設定画面の導線。
  static const Key entryFromSettings = Key('row_settings_google_todo');
}
