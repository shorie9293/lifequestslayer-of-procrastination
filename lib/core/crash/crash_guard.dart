import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:rpg_todo/core/crash/crash_log_service.dart';

/// 直近に装着したハンドラ（再装着の判定に使う）。
FlutterExceptionHandler? _installedFlutterHandler;
ErrorCallback? _installedPlatformHandler;
bool _flutterInstalled = false;
bool _platformInstalled = false;

/// 未捕捉例外を「既存ハンドラへ委譲しつつ端末内ログにも記録」する合流点を作る。
///
/// - [FlutterError.onError] … 既存ハンドラ（Crashlytics + presentError 等）を
///   先に呼び、その後で自前ログへ記録する。既存の挙動は変えない。
/// - [PlatformDispatcher.onError] … 既存ハンドラの戻り値（true=処理済み）を尊重し、
///   未設定なら false を返す。
///
/// 既に装着済み（同一ハンドラが入っている）なら何もしない＝何度呼んでも安全。
/// ただし main が後からハンドラを上書きした場合は、その新しいハンドラを
/// 既存側として再装着できる（呼び直し可能）。
void installCrashGuard({CrashLogger? logger}) {
  final log = logger ?? crashLogger;

  final flutterAlready = _flutterInstalled &&
      identical(FlutterError.onError, _installedFlutterHandler);
  if (!flutterAlready) {
    final previous = FlutterError.onError;
    _installedFlutterHandler = (FlutterErrorDetails details) {
      try {
        log.record(details.exception, details.stack, kind: 'flutter');
      } catch (_) {
        // 記録の失敗が既存処理を止めてはならない。
      }
      previous?.call(details);
    };
    FlutterError.onError = _installedFlutterHandler;
    _flutterInstalled = true;
  }

  final platformAlready = _platformInstalled &&
      identical(PlatformDispatcher.instance.onError, _installedPlatformHandler);
  if (!platformAlready) {
    final previous = PlatformDispatcher.instance.onError;
    _installedPlatformHandler = (Object error, StackTrace stack) {
      try {
        log.record(error, stack, kind: 'platform');
      } catch (_) {
        // 同上。
      }
      if (previous == null) return false;
      return previous(error, stack);
    };
    PlatformDispatcher.instance.onError = _installedPlatformHandler;
    _platformInstalled = true;
  }
}

/// 装着状態を戻す（試練用）。元のハンドラへ復帰する。
@visibleForTesting
void uninstallCrashGuard() {
  FlutterError.onError = null;
  PlatformDispatcher.instance.onError = null;
  _installedFlutterHandler = null;
  _installedPlatformHandler = null;
  _flutterInstalled = false;
  _platformInstalled = false;
}
