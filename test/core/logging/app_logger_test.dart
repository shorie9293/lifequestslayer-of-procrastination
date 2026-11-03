import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    late List<String> logs;
    late AppLogger logger;

    setUp(() {
      logs = <String>[];
      logger = AppLogger(isDebug: false, sink: logs.add);
    });

    test('isDebug=false のとき debug は出力しない', () {
      logger.debug('debug message');
      expect(logs, isEmpty);
    });

    test('isDebug=false のとき info は出力しない', () {
      logger.info('info message');
      expect(logs, isEmpty);
    });

    test('isDebug=true のとき debug / info を出力する（レベルタグ付き）', () {
      final debugLog = <String>[];
      final verbose = AppLogger(isDebug: true, sink: debugLog.add);

      verbose.debug('debug message');
      verbose.info('info message');

      expect(debugLog.length, 2);
      expect(debugLog[0], '[DEBUG] debug message');
      expect(debugLog[1], '[INFO] info message');
    });

    test('warn は isDebug=false でも出力する', () {
      logger.warn('warn message');
      expect(logs.single, '[WARN] warn message');
    });

    test('error は isDebug=false でも出力する', () {
      logger.error('error message');
      expect(logs.single, '[ERROR] error message');
    });

    test('warn は例外とスタックトレースを併記する', () {
      final error = StateError('boom');
      final stack = StackTrace.current;

      logger.warn('warn with error', error, stack);

      expect(logs.single, startsWith('[WARN] warn with error'));
      expect(logs.single, contains('boom'));
    });

    test('error は例外とスタックトレースを併記する', () {
      final error = StateError('boom');
      final stack = StackTrace.current;

      logger.error('error with error', error, stack);

      expect(logs.single, startsWith('[ERROR] error with error'));
      expect(logs.single, contains('boom'));
      expect(logs.single, contains('app_logger_test.dart'));
    });

    test('例外付き error でも throw しない', () {
      expect(
        () => logger.error('never throws', Exception('fatal'), StackTrace.empty),
        returnsNormally,
      );
    });

    test('sink を差し替えられる（1呼び出し1行）', () {
      final custom = <String>[];
      final injected = AppLogger(isDebug: true, sink: custom.add);

      injected.debug('a');
      injected.info('b');
      injected.warn('c');
      injected.error('d');

      expect(custom, <String>['[DEBUG] a', '[INFO] b', '[WARN] c', '[ERROR] d']);
    });

    test('既定の appLog はインスタンスで isDebug が kDebugMode に追従する', () {
      expect(appLog, isA<AppLogger>());
      expect(appLog.isDebug, kDebugMode);
    });
  });
}
