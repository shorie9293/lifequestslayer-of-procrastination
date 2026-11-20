import 'package:flutter/material.dart';

/// 削除Undo用 SnackBar のアクションボタン識別子（試練用）。
const undoActionKey = Key('undo_snackbar_action');

/// 「元に戻す」アクション付き SnackBar を表示する。
///
/// 削除は即時実行のまま、直後にこの SnackBar で取り消し導線を出す。
///
/// **`persist` は明示的に false にする。** Flutter 3.47 以降、`action` を持つ
/// `SnackBar` は `persist` の既定が true になり、`duration` を過ぎても
/// 自動では消えない（＝削除のたびに「元に戻す」バーが画面に残り続ける禍津）。
/// 破棄Undoは有限時間で消える契約なので、ここで必ず無効化する。
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
      persist: false,
      action: SnackBarAction(
        key: undoActionKey,
        label: '元に戻す',
        onPressed: onUndo,
      ),
    ),
  );
}
