import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/widgets/load_state_views.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('LoadErrorView は文言と再試行ボタンを表示する', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      LoadErrorView(message: '戦績を読み込めませんでした', onRetry: () => taps++),
    );
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    expect(find.text('戦績を読み込めませんでした'), findsOneWidget);
    expect(find.byKey(const ValueKey('load_retry_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('load_retry_button')));
    expect(taps, 1);
  });

  testWidgets('LoadErrorView は onRetry が null なら再試行を出さない', (tester) async {
    await _pump(tester, const LoadErrorView(message: '再試行できません'));
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
    expect(find.text('再試行'), findsNothing);
  });

  testWidgets('LoadEmptyView は空文言のみを表示し、エラー表示を混ぜない', (tester) async {
    await _pump(tester, const LoadEmptyView(message: 'まだ記録がありません'));
    expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
    expect(find.text('まだ記録がありません'), findsOneWidget);
    expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
    expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
  });

  testWidgets('error と empty は同時に現れない（別ウィジェット・別Key）', (tester) async {
    await _pump(tester, const LoadEmptyView(message: '0件です'));
    expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
    expect(find.byKey(const ValueKey('load_error_view')), findsNothing);

    await _pump(tester, const LoadErrorView(message: '失敗しました'));
    expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
  });
}
