import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/crash/crash_guard.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_service.dart';

void main() {
  final originalFlutterOnError = FlutterError.onError;
  final originalPlatformOnError = PlatformDispatcher.instance.onError;

  tearDown(() {
    uninstallCrashGuard();
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  test('FlutterError.onError は既存ハンドラより先に呼ばれ、記録もされる', () async {
    final repo = InMemoryCrashLogRepository();
    final logger = CrashLogger(repository: repo);
    var existingCalls = 0;

    FlutterError.onError = (FlutterErrorDetails details) => existingCalls++;
    installCrashGuard(logger: logger);
    expect(FlutterError.onError, isNot(same(null)));

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('どかん')));
    await Future<void>.delayed(Duration.zero);

    // 既存ハンドラは従来通り呼ばれる（挙動不変）。
    expect(existingCalls, 1);
    final entries = await repo.loadAll();
    expect(entries.length, 1);
    expect(entries.single.kind, 'flutter');
    expect(entries.single.message, contains('どかん'));
  });

  test('PlatformDispatcher.onError は既存の戻り値（true=処理済み）を尊重する', () async {
    final repo = InMemoryCrashLogRepository();
    final logger = CrashLogger(repository: repo);
    var existingCalls = 0;

    PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
      existingCalls++;
      return true;
    };
    installCrashGuard(logger: logger);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('プラットフォーム例外'),
      StackTrace.current,
    );
    await Future<void>.delayed(Duration.zero);

    expect(handled, isTrue);
    expect(existingCalls, 1);
    final entries = await repo.loadAll();
    expect(entries.length, 1);
    expect(entries.single.kind, 'platform');
  });

  test('既存ハンドラが無ければ false を返す', () async {
    PlatformDispatcher.instance.onError = null;
    installCrashGuard(
        logger: CrashLogger(repository: InMemoryCrashLogRepository()));

    expect(
      PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.current),
      isFalse,
    );
  });

  test('二度呼んでもハンドラを二重に包まない', () async {
    final repo = InMemoryCrashLogRepository();
    final logger = CrashLogger(repository: repo);
    var existingCalls = 0;
    FlutterError.onError = (FlutterErrorDetails details) => existingCalls++;

    installCrashGuard(logger: logger);
    installCrashGuard(logger: logger);

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('x')));
    await Future<void>.delayed(Duration.zero);

    expect(existingCalls, 1);
    expect((await repo.loadAll()).length, 1);
  });
}
