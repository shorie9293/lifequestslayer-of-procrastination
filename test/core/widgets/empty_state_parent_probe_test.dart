import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/widgets/empty_state.dart';

/// 親探針（イシコリドメ本体が実測）: 空状態部品の契約を固定する。
/// 子の試練は自前の期待値を書くため、契約の骨格だけを親が独立に撃つ。
void main() {
  test('仕様: 見出しが空なら ArgumentError', () {
    expect(() => EmptyStateSpec(title: ''), throwsArgumentError);
    expect(() => EmptyStateSpec(title: '   '), throwsArgumentError);
  });

  test('仕様: actionLabel と onAction は片方だけでは作れない', () {
    expect(() => EmptyStateSpec(title: 'x', actionLabel: 'する'),
        throwsArgumentError);
    expect(() => EmptyStateSpec(title: 'x', onAction: () {}), throwsArgumentError);
    expect(
        () => EmptyStateSpec(title: 'x', actionLabel: 'する', onAction: () {}),
        returnsNormally);
  });

  testWidgets('描画: 行動ボタンは1つだけ・押すと onAction が1回呼ばれる', (tester) async {
    var taps = 0;
    final spec = EmptyStateSpec(
      title: 'まだありません',
      description: '追加すると始まります',
      actionLabel: '追加する',
      onAction: () => taps++,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyStateView(key: const Key('probe'), spec: spec)),
    ));
    expect(find.text('まだありません'), findsOneWidget);
    expect(find.text('追加すると始まります'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('追加する'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('描画: onAction なしならボタンを描かない', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyStateView(
          key: const Key('probe2'),
          spec: EmptyStateSpec(title: 'まだありません'),
        ),
      ),
    ));
    expect(find.text('まだありません'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
