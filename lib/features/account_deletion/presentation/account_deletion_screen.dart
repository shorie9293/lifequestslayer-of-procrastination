import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:rpg_todo/features/account_deletion/domain/account_deletion_policy.dart';
import 'package:rpg_todo/features/account_deletion/domain/account_deletion_service.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_app_keys.dart';

/// アカウント削除（退会）画面 — 2段階確認。
///
/// 第1段階: 何が消えるかの列挙と注意書きを提示。
/// 第2段階: 「削除する」→ 確認文字入力ダイアログ → 完全一致でのみ実行。
///
/// 有効なセッションが無い（[hasActiveSession] が false）場合は実行しない。
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    super.key,
    required this.service,
    this.policy = const AccountDeletionPolicy(),
    this.hasActiveSession = true,
    this.targetLabels = AccountDeletionPolicy.targetLabels,
    this.onDeleted,
  });

  final AccountDeletionService service;
  final AccountDeletionPolicy policy;
  final bool hasActiveSession;
  final List<String> targetLabels;

  /// 削除成功時の後処理（本番はサインアウト後の再起動導線などに使う）。
  final VoidCallback? onDeleted;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _running = false;
  bool _succeeded = false;
  String? _errorMessage;

  Future<void> _onDeletePressed() async {
    if (_running || !widget.policy.canDelete(
      hasActiveSession: widget.hasActiveSession,
    )) {
      return;
    }

    final input = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmDialog(phrase: AccountDeletionPolicy.confirmationPhrase),
    );

    if (!mounted || input == null) return;

    if (!widget.policy.isConfirmationSatisfied(
      input: input,
      expected: AccountDeletionPolicy.confirmationPhrase,
    )) {
      setState(() {
        _errorMessage = '確認文字が一致しません。削除は実行していません。';
      });
      return;
    }

    setState(() {
      _running = true;
      _errorMessage = null;
    });

    final result = await widget.service.execute(confirmed: true);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _running = false;
        _errorMessage = result.message.isEmpty
            ? '削除に失敗しました。再試行してください。'
            : result.message;
      });
      return;
    }

    setState(() {
      _running = false;
      _succeeded = true;
    });
    widget.onDeleted?.call();

    // 成功文言を読ませてから画面を閉じる。
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.targetLabels;
    final canDelete = widget.policy.canDelete(
      hasActiveSession: widget.hasActiveSession,
    );

    return Scaffold(
      key: AccountDeletionAppKeys.screen,
      appBar: AppBar(title: const Text('アカウント削除')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'アカウント削除（退会）',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(widget.policy.summary(labels)),
          const SizedBox(height: 16),
          const Text(
            '注意: 削除したデータは復元できません。必要なデータは'
            '「自動バックアップ」から控えてください。',
          ),
          const SizedBox(height: 8),
          const Text(
            'この操作で消えるのは端末内のデータです。'
            'サーバ上のアカウントは残ります（サーバ側削除は準備中）。',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 16),
          if (!canDelete)
            const Text(
              'ログインしていないため、アカウント削除は実行できません。',
              style: TextStyle(color: Color(0xFFB00020)),
            ),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              key: AccountDeletionAppKeys.errorMessage,
              style: const TextStyle(color: Color(0xFFB00020)),
            ),
          if (_succeeded)
            const Text(
              '端末内のデータを削除し、サインアウトしました。'
              'ご利用ありがとうございました。',
              key: AccountDeletionAppKeys.successMessage,
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
              SemanticTypes.button,
              'account_deletion_delete',
            ),
            label: 'アカウントを削除する',
            child: FilledButton(
              key: AccountDeletionAppKeys.deleteButton,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB00020),
              ),
              onPressed: (_running || _succeeded || !canDelete)
                  ? null
                  : _onDeletePressed,
              child: Text(_running ? '削除しています…' : '削除する'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 確認文字入力ダイアログ。[confirmButton] で入力値を返す。
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.phrase});

  final String phrase;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('本当に削除しますか？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('続行するには「${widget.phrase}」と入力してください。'),
          TextField(
            key: AccountDeletionAppKeys.confirmField,
            controller: _controller,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: AccountDeletionAppKeys.cancelButton,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        TextButton(
          key: AccountDeletionAppKeys.confirmButton,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('削除する'),
        ),
      ],
    );
  }
}
