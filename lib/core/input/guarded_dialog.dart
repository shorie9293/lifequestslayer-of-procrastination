import 'package:flutter/material.dart';

import 'package:rpg_todo/core/input/unsaved_changes.dart';

/// 入力途中の破棄を確認するダイアログを出す。
///
/// 「破棄する」で true。外側タップ・戻る操作などで閉じた場合は false
/// （＝編集を続ける側に倒す）。
Future<bool> confirmDiscard(
  BuildContext context, {
  String? message,
  String discardLabel = UnsavedChangesGuard.discardLabel,
  String keepLabel = UnsavedChangesGuard.keepLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('unsaved_changes_dialog'),
        title: const Text('入力内容の確認'),
        content: Text(message ?? UnsavedChangesGuard.defaultMessage),
        actions: [
          TextButton(
            key: const Key('unsaved_changes_keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(keepLabel),
          ),
          TextButton(
            key: const Key('unsaved_changes_discard'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(discardLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// 入力が残っている間は、外側タップ・戻る操作で勝手に閉じないダイアログ。
///
/// 未入力（[isDirty] が false）なら従来どおり外側タップで閉じられる
/// ＝操作性を落とさない。入力があるときだけ確認を挟む。
Future<T?> showGuardedDialog<T>({
  required BuildContext context,
  required bool Function() isDirty,
  required WidgetBuilder builder,
  String? message,
  bool closeOnBarrierTapWhenClean = true,
  bool useRootNavigator = true,
}) {
  final localizations = MaterialLocalizations.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: localizations.modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 150),
    useRootNavigator: useRootNavigator,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _GuardedDialogHost(
        isDirty: isDirty,
        message: message,
        closeOnBarrierTapWhenClean: closeOnBarrierTapWhenClean,
        child: builder(dialogContext),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _GuardedDialogHost extends StatelessWidget {
  const _GuardedDialogHost({
    required this.isDirty,
    required this.child,
    required this.closeOnBarrierTapWhenClean,
    this.message,
  });

  final bool Function() isDirty;
  final Widget child;
  final bool closeOnBarrierTapWhenClean;
  final String? message;

  Future<void> _requestClose(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (!isDirty()) {
      if (closeOnBarrierTapWhenClean) navigator.pop();
      return;
    }

    final discard = await confirmDiscard(context, message: message);
    if (!context.mounted) return;
    if (discard) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('guarded_dialog_barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _requestClose(context),
          ),
        ),
        Center(
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _requestClose(context);
            },
            child: child,
          ),
        ),
      ],
    );
  }
}
