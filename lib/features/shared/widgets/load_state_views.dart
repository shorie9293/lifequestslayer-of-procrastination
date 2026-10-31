import 'package:flutter/material.dart';

/// 読込失敗の共通表示。
///
/// 「0件」とは別ウィジェット・別文言・別 Key とし、失敗を空状態に
/// 見せかけない。[onRetry] が null なら再試行導線は出さない。
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({super.key, required this.message, this.onRetry});

  /// 失敗理由（日本語）。
  final String message;

  /// 再試行処理。null なら再試行ボタンを表示しない。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Center(
      key: const ValueKey('load_error_view'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
            if (retry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('load_retry_button'),
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 0件（失敗ではない）の共通表示。
class LoadEmptyView extends StatelessWidget {
  const LoadEmptyView({super.key, required this.message});

  /// 空状態の説明（日本語）。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('load_empty_view'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
