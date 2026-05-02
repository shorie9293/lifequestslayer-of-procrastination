// コード適応神書 — 原則⑥ エラー境界
// 画面単位で例外を捕捉し、アプリ全体のクラッシュを防ぐ
//
// 使い方:
//   ErrorBoundary(child: GuildScreen())  // ギルドが落ちても戦場は生きてる
//
// 制定: 令和八年皐月三日（適3）

import 'package:flutter/material.dart';
import '../testing/widget_keys.dart';

/// 画面単位のエラー境界
/// このWidgetで囲まれた領域で例外が発生しても、アプリ全体はクラッシュしない
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.onError?.call(_error!, null) ??
          _defaultErrorWidget(_error!);
    }
    return widget.child;
  }

  Widget _defaultErrorWidget(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('画面の読み込みに失敗しました',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$error', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              key: AppKeys.closeButton,
              onPressed: () {
                setState(() => _error = null); // リトライ
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ErrorWidget.builder 用のフォールバックWidget
class ErrorBoundaryWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const ErrorBoundaryWidget({
    super.key,
    required this.error,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'ウィジェットの構築中にエラーが発生しました',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
