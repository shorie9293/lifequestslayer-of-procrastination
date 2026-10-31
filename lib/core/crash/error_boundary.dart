import 'package:flutter/material.dart';
import 'package:rpg_todo/core/crash/crash_log_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart'
    hide AppKeys, ErrorBoundary;

/// 表示中の Widget ツリーで例外が起きた時に「1画面の復帰UI」を出す境界。
///
/// - `initState` で [ErrorWidget.builder] を差し替え、build 中の例外を捕捉する。
/// - 元の builder は保持し、`dispose` で必ず戻す（既存 MaterialApp を壊さない）。
/// - 「再読み込み」で generation を進めて `child` を再構築する。
///   （同じ child が2回目は成功するなら通常表示へ戻る）
/// - 記録は [CrashLogger] へ投げっぱなしで渡す（既定は端末内ログ）。
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onReload,
    this.logger,
  });

  final Widget child;

  /// 再読み込み時に呼ばれる追加処理（任意）。
  final VoidCallback? onReload;

  /// 記録先（試練では InMemory 実装を注入する）。
  final CrashLogger? logger;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  ErrorWidgetBuilder? _previousBuilder;
  Object? _error;
  int _generation = 0;

  CrashLogger get _logger => widget.logger ?? crashLogger;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = _onBuildError;
  }

  @override
  void dispose() {
    final previous = _previousBuilder;
    if (previous != null) ErrorWidget.builder = previous;
    super.dispose();
  }

  /// build 中の例外を捕捉。setState は build 中に呼べないので次フレームへ回す。
  Widget _onBuildError(FlutterErrorDetails details) {
    _logger.record(details.exception, details.stack, kind: 'widget-build');
    if (_error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _error = details.exception);
      });
    }
    return const _BoundaryFallbackBody();
  }

  void _reload() {
    widget.onReload?.call();
    setState(() {
      _error = null;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _crashScreen();
    return KeyedSubtree(
      key: ValueKey<int>(_generation),
      child: widget.child,
    );
  }

  Widget _crashScreen() {
    return Material(
      key: AppKeys.crashBoundaryScreen,
      color: const Color(0xFF1E1A26),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_moon_outlined,
                size: 56,
                color: Color(0xFFD9A441),
              ),
              const SizedBox(height: 16),
              const Text(
                '表示中に問題が発生しました',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ご迷惑をおかけしました。再読み込みで復帰できます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFFB8B2C4)),
              ),
              const SizedBox(height: 24),
              SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                  SemanticTypes.button,
                  'crash_boundary_reload',
                ),
                label: '再読み込み',
                child: FilledButton.icon(
                  key: AppKeys.crashBoundaryReloadButton,
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再読み込み'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [ErrorWidget.builder] の戻り値として出す最小限の代替表示。
class _BoundaryFallbackBody extends StatelessWidget {
  const _BoundaryFallbackBody();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF1E1A26),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'この部分の表示に問題が発生しました',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
