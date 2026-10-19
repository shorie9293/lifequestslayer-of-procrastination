import 'package:flutter/material.dart';

/// 削除Undo用 SnackBar のアクションボタン識別子（試練用）。
const undoActionKey = Key('undo_snackbar_action');

/// 「元に戻す」アクション付き SnackBar を表示する。
///
/// 削除は即時実行のまま、直後にこの SnackBar で取り消し導線を出す。
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(
        key: undoActionKey,
        label: '元に戻す',
        onPressed: onUndo,
      ),
    ),
  );
}
