// 削除Undo用 SnackBar のウィジェット試練。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/undo/presentation/undo_snack_bar.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
    String message = 'クエストを削除しました',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showUndoSnackBar(
                  context,
                  message: message,
                  onUndo: onUndo,
                  duration: duration,
                ),
                child: const Text('削除する'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('showUndoSnackBar で文言と「元に戻す」アクションが出る', (tester) async {
    await pumpHost(tester, onUndo: () {});

    await tester.tap(find.text('削除する'));
    await tester.pump();

    expect(find.text('クエストを削除しました'), findsOneWidget);
    expect(find.text('元に戻す'), findsOneWidget);
    expect(find.byKey(undoActionKey), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 5));

    await tester.pumpAndSettle();
  });

  testWidgets('「元に戻す」タップで onUndo が1回だけ呼ばれる', (tester) async {
    var calls = 0;
    await pumpHost(tester, onUndo: () => calls++);

    await tester.tap(find.text('削除する'));
    await tester.pump();
    expect(calls, 0);

    // SnackBar の登場アニメーションを進めてからアクションを押す
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(undoActionKey));
    await tester.pump();
    expect(calls, 1);

    // アクションは消え、二度目は起こらない
    await tester.pumpAndSettle();
    expect(find.byKey(undoActionKey), findsNothing);
    expect(calls, 1);
  });

  testWidgets('duration を差し替えられる（既定5秒を上書き）', (tester) async {
    await pumpHost(
      tester,
      onUndo: () {},
      duration: const Duration(seconds: 2),
      message: '一括削除しました',
    );

    await tester.tap(find.text('削除する'));
    await tester.pump();

    expect(find.text('一括削除しました'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 2));

    await tester.pumpAndSettle();
  });
}
