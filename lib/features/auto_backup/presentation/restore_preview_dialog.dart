import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/auto_backup/domain/restore_preview.dart';

/// 復元確認ダイアログの本文。
///
/// 従来の一文（[message]）はそのまま先頭に置き、プレビューが取れた時だけ
/// 内訳（要約・一文・上書き対象キーの抜粋）を足す。
/// [preview] が null なら従来表示のみ（復元導線を止めない）。
class RestorePreviewContent extends StatelessWidget {
  const RestorePreviewContent({
    super.key,
    required this.message,
    this.preview,
  });

  /// 従来の確認文言（既存文言を変えない）。
  final String message;

  /// 内訳プレビュー。取得できなければ null。
  final RestorePreview? preview;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (preview != null) ...[
            const SizedBox(height: 12),
            Text(
              preview.summary,
              key: AppKeys.restorePreviewSummary,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(preview.message),
            if (preview.replacedText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(preview.replacedText!),
              ),
            if (preview.samplesText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  preview.samplesText!,
                  key: AppKeys.restorePreviewSamples,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 復元確認ダイアログを表示し、確定なら true。
///
/// [dialogKey] / [cancelKey] / [confirmKey] は呼出側の既存 Key をそのまま渡す
/// （自動バックアップ画面は [AutoBackupKeys]、手動リストアは [AppKeys]）。
Future<bool> showRestorePreviewDialog({
  required BuildContext context,
  required Key dialogKey,
  required String message,
  required RestorePreview? preview,
  Key? cancelKey,
  Key? confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: dialogKey,
      title: const Text('復元の確認'),
      content: RestorePreviewContent(message: message, preview: preview),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('復元する'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
