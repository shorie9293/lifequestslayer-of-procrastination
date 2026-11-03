import 'package:flutter/foundation.dart';

/// ログの出力先。試練では差し替えて検証する。
typedef LogSink = void Function(String message);

/// 本番で垂れ流さない構造化ロガー。
///
/// - [debug] / [info] はデバッグビルドのみ出力（リリースビルドでは黙る）
/// - [warn] / [error] は常に出力（本番の異常を握り潰さない）
/// - 出力は必ず `[LEVEL] ` のタグで始まり、1呼び出し1行に収める
/// - 例外を絶対に throw しない（ログが原因でアプリを落とさない）
class AppLogger {
  AppLogger({bool? isDebug, LogSink? sink})
      : isDebug = isDebug ?? kDebugMode,
        _sink = sink ?? debugPrint;

  /// デバッグ系ログを出力してよいか。既定は [kDebugMode] に追従。
  final bool isDebug;

  final LogSink _sink;

  void debug(String message) {
    if (!isDebug) return;
    _emit('[DEBUG] $message');
  }

  void info(String message) {
    if (!isDebug) return;
    _emit('[INFO] $message');
  }

  void warn(String message, [Object? error, StackTrace? stackTrace]) {
    _emit('[WARN] $message', error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _emit('[ERROR] $message', error, stackTrace);
  }

  void _emit(String tagged, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(tagged);
    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stackTrace != null) {
      buffer.write(' | stack: $stackTrace');
    }
    try {
      _sink(buffer.toString());
    } catch (_) {
      // ログ出力自体の失敗は無視する（本番を止めない）。
    }
  }
}

/// アプリ全体で共有するロガー。既定では [kDebugMode] に追従する。
final appLog = AppLogger();
