// 空状態共通部品（EmptyStateSpec / EmptyStateView）の試練。
//
// 不変条件はリリースビルドでも効くよう ArgumentError で強制される（assert ではない）ため、
// ここでは throwA ではなく throwsArgumentError で検める。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/widgets/empty_state.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('EmptyStateSpec の不変条件', () {
    test('title が空文字なら ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: ''),
        throwsArgumentError,
      );
    });

    test('title が空白のみでも ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: '   '),
        throwsArgumentError,
      );
    });

    test('actionLabel だけ指定して onAction が無ければ ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: 'まだありません', actionLabel: '追加する'),
        throwsArgumentError,
      );
    });

    test('onAction だけ指定して actionLabel が無ければ ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: 'まだありません', onAction: () {}),
        throwsArgumentError,
      );
    });

    test('actionLabel が空文字なら ArgumentError', () {
      expect(
        () => EmptyStateSpec(
          title: 'まだありません',
          actionLabel: '',
          onAction: () {},
        ),
        throwsArgumentError,
      );
    });

    test('title と description だけの最小構成は生成できる', () {
      final spec = EmptyStateSpec(
        title: 'まだありません',
        description: '右下の + で追加できます',
      );
      expect(spec.title, 'まだありません');
      expect(spec.description, '右下の + で追加できます');
      expect(spec.actionLabel, isNull);
      expect(spec.onAction, isNull);
    });

    test('actionLabel と onAction の対は保持される', () {
      void action() {}
      final spec = EmptyStateSpec(
        title: 'まだありません',
        actionLabel: '追加する',
        onAction: action,
      );
      expect(spec.actionLabel, '追加する');
      expect(spec.onAction, same(action));
    });
  });

  group('EmptyStateView の描画', () {
    testWidgets('title と description を描画する', (tester) async {
      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_basic'),
        spec: EmptyStateSpec(
          title: 'まだクエストがない',
          description: '＋ から追加しよう',
        ),
      )));

      expect(find.text('まだクエストがない'), findsOneWidget);
      expect(find.text('＋ から追加しよう'), findsOneWidget);
    });

    testWidgets('description が null なら見出しのみ', (tester) async {
      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_no_desc'),
        spec: EmptyStateSpec(title: 'まだ記録がない'),
      )));

      expect(find.text('まだ記録がない'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('description が空文字なら描画しない', (tester) async {
      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_blank_desc'),
        spec: EmptyStateSpec(title: 'まだ記録がない', description: ''),
      )));

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('icon を渡すと描画し、渡さなければ描画しない', (tester) async {
      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_icon'),
        icon: const Icon(Icons.inbox),
        spec: EmptyStateSpec(title: 'まだない'),
      )));
      expect(find.byIcon(Icons.inbox), findsOneWidget);

      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_no_icon'),
        spec: EmptyStateSpec(title: 'まだない'),
      )));
      expect(find.byIcon(Icons.inbox), findsNothing);
    });

    testWidgets('actionLabel を渡すとボタンを描画し、押下で onAction が発火する', (tester) async {
      var fired = 0;
      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_action'),
        spec: EmptyStateSpec(
          title: 'まだクエストがない',
          actionLabel: '最初のクエストを登録する',
          onAction: () => fired++,
        ),
      )));

      expect(find.widgetWithText(FilledButton, '最初のクエストを登録する'), findsOneWidget);
      await tester.tap(find.text('最初のクエストを登録する'));
      await tester.pump();
      expect(fired, 1);
    });

    testWidgets('actionLabel が null ならボタンを描画しない', (tester) async {
      await tester.pumpWidget(_host(EmptyStateView(
        key: const Key('view_empty_no_action'),
        spec: EmptyStateSpec(title: 'まだクエストがない'),
      )));

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });
  });
}
