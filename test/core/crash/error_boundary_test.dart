import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_service.dart';
import 'package:rpg_todo/core/crash/error_boundary.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 初回 build だけ失敗し、以後は成功する子。
int _buildCount = 0;

Widget _flakyChild() {
  return Builder(
    builder: (context) {
      _buildCount++;
      if (_buildCount == 1) {
        throw StateError('初回 build の失敗');
      }
      return const Text('正常表示');
    },
  );
}

void main() {
  setUp(() => _buildCount = 0);

  testWidgets('child の build 例外を捕捉して復帰UIを出す', (tester) async {
    final repo = InMemoryCrashLogRepository();
    final logger = CrashLogger(repository: repo);
    final originalBuilder = ErrorWidget.builder;

    await tester.pumpWidget(
      MaterialApp(home: ErrorBoundary(logger: logger, child: _flakyChild())),
    );

    // build 中の例外はフレームワークへ報告される（既存挙動は殺さない）。
    expect(tester.takeException(), isA<StateError>());

    // post-frame の setState 後に復帰UIへ切り替わる。
    await tester.pump();

    expect(find.byKey(AppKeys.crashBoundaryScreen), findsOneWidget);
    expect(find.text('表示中に問題が発生しました'), findsOneWidget);
    expect(find.byKey(AppKeys.crashBoundaryReloadButton), findsOneWidget);
    expect(find.text('正常表示'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(ErrorWidget.builder, same(originalBuilder));
  });

  testWidgets('再読み込みで child が再構築され正常表示に戻る', (tester) async {
    final repo = InMemoryCrashLogRepository();
    final logger = CrashLogger(repository: repo);
    var reloads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          logger: logger,
          onReload: () => reloads++,
          child: _flakyChild(),
        ),
      ),
    );
    expect(tester.takeException(), isA<StateError>());
    await tester.pump();
    expect(find.byKey(AppKeys.crashBoundaryScreen), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.crashBoundaryReloadButton));
    await tester.pumpAndSettle();

    expect(reloads, 1);
    expect(find.byKey(AppKeys.crashBoundaryScreen), findsNothing);
    expect(find.text('正常表示'), findsOneWidget);
  });

  testWidgets('捕捉した例外は端末内ログへ記録される', (tester) async {
    final repo = InMemoryCrashLogRepository();
    final logger = CrashLogger(repository: repo);

    await tester.pumpWidget(
      MaterialApp(home: ErrorBoundary(logger: logger, child: _flakyChild())),
    );
    expect(tester.takeException(), isA<StateError>());
    await tester.pump();
    await tester.pump(Duration.zero);

    final entries = await repo.loadAll();
    expect(entries, isNotEmpty);
    expect(entries.first.kind, 'widget-build');
    expect(entries.first.message, contains('初回 build の失敗'));
  });
}
