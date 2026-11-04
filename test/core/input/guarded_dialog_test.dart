import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/input/guarded_dialog.dart';
import 'package:rpg_todo/core/input/unsaved_changes.dart';

/// ダイアログを開くだけの器。入力欄は開いた後も保持される。
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _open() {
    return showGuardedDialog<void>(
      context: context,
      isDirty: () => UnsavedChangesGuard.isDirty('', _controller.text),
      builder: (dialogContext) => AlertDialog(
        key: const Key('test_dialog'),
        content: TextField(
          key: const Key('test_dialog_field'),
          controller: _controller,
        ),
        actions: [
          TextButton(
            key: const Key('test_dialog_close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('open_dialog'),
          onPressed: _open,
          child: const Text('開く'),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_dialog')));
  await tester.pumpAndSettle();
}

Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('未入力なら外側タップで従来どおり閉じる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Host()));
    await _open(tester);
    expect(find.byKey(const Key('test_dialog')), findsOneWidget);

    await _tapOutside(tester);

    expect(find.byKey(const Key('test_dialog')), findsNothing);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsNothing);
  });

  testWidgets('入力後に外側タップすると閉じずに確認が出る', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Host()));
    await _open(tester);
    await tester.enterText(
        find.byKey(const Key('test_dialog_field')), '書きかけの長文');
    await tester.pumpAndSettle();

    await _tapOutside(tester);

    expect(find.byKey(const Key('test_dialog')), findsOneWidget);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsOneWidget);
  });

  testWidgets('「編集を続ける」で本文が残る', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Host()));
    await _open(tester);
    await tester.enterText(
        find.byKey(const Key('test_dialog_field')), '書きかけの長文');
    await tester.pumpAndSettle();
    await _tapOutside(tester);

    await tester.tap(find.byKey(const Key('unsaved_changes_keep')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unsaved_changes_dialog')), findsNothing);
    expect(find.byKey(const Key('test_dialog')), findsOneWidget);
    expect(find.text('書きかけの長文'), findsOneWidget);
  });

  testWidgets('「破棄する」で閉じる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Host()));
    await _open(tester);
    await tester.enterText(
        find.byKey(const Key('test_dialog_field')), '書きかけの長文');
    await tester.pumpAndSettle();
    await _tapOutside(tester);

    await tester.tap(find.byKey(const Key('unsaved_changes_discard')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unsaved_changes_dialog')), findsNothing);
    expect(find.byKey(const Key('test_dialog')), findsNothing);
  });

  testWidgets('戻る操作でも同じ確認が出る', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Host()));
    await _open(tester);
    await tester.enterText(
        find.byKey(const Key('test_dialog_field')), '書きかけの長文');
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('test_dialog')));
    await Navigator.of(context).maybePop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test_dialog')), findsOneWidget);
    expect(find.byKey(const Key('unsaved_changes_dialog')), findsOneWidget);
  });
}
