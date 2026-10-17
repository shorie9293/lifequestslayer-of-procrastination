import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';
import 'package:rpg_todo/features/town/presentation/widgets/town_event_gate.dart';

const _merchant = RandomEvent(
  type: EventType.merchant,
  title: '旅の商人',
  description: '特別な品を仕入れてきたぞ',
  emoji: '🏪',
  reward: {'xp': 50, 'gems': 3},
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TownEventGate', () {
    testWidgets('checkEvent が null なら何もしない（子だけ表示）', (tester) async {
      await tester.pumpWidget(_wrap(
        const TownEventGate(
          child: Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('町のコンテンツ'), findsOneWidget);
      expect(find.byKey(AppKeys.townEventOverlay), findsNothing);
    });

    testWidgets('イベントが返れば overlay が町の上に重なる', (tester) async {
      await tester.pumpWidget(_wrap(
        TownEventGate(
          checkEvent: () async => _merchant,
          child: const Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.townEventOverlay), findsOneWidget);
      expect(find.byKey(AppKeys.townEventTitle), findsOneWidget);
      expect(find.text('旅の商人'), findsOneWidget);
      expect(find.byKey(AppKeys.townEventDescription), findsOneWidget);
      expect(find.text('特別な品を仕入れてきたぞ'), findsOneWidget);
      // 背後の町コンテンツは消えない（overlay であって画面差し替えではない）
      expect(find.text('町のコンテンツ'), findsOneWidget);
    });

    testWidgets('抽選に漏れたら overlay は出ない', (tester) async {
      await tester.pumpWidget(_wrap(
        TownEventGate(
          checkEvent: () async => null,
          child: const Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.townEventOverlay), findsNothing);
    });

    testWidgets('閉じるボタンで overlay が消える', (tester) async {
      await tester.pumpWidget(_wrap(
        TownEventGate(
          checkEvent: () async => _merchant,
          child: const Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.townEventClose));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.townEventOverlay), findsNothing);
      expect(find.text('町のコンテンツ'), findsOneWidget);
    });

    testWidgets('抽選器が例外を投げても町は壊れない', (tester) async {
      await tester.pumpWidget(_wrap(
        TownEventGate(
          checkEvent: () async => throw StateError('抽選器の禍津'),
          child: const Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('町のコンテンツ'), findsOneWidget);
      expect(find.byKey(AppKeys.townEventOverlay), findsNothing);
    });

    testWidgets('抽選は1回だけ（rebuild で再抽選しない）', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(
        TownEventGate(
          checkEvent: () async {
            calls++;
            return null;
          },
          child: const Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      // 再ビルドを強制
      await tester.pumpWidget(_wrap(
        TownEventGate(
          checkEvent: () async {
            calls++;
            return null;
          },
          child: const Text('町のコンテンツ'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('onEventShown は表示時に1回だけ呼ばれる（再ビルドで二重付与しない）', (tester) async {
      var shown = 0;
      RandomEvent? received;
      const child = Text('町のコンテンツ');

      Widget build() => _wrap(
            TownEventGate(
              checkEvent: () async => _merchant,
              onEventShown: (event) {
                shown++;
                received = event;
              },
              child: child,
            ),
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(shown, 1);
      expect(received?.title, '旅の商人');

      // 再ビルド（同一 State を再利用）
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(shown, 1, reason: '報酬の二重付与を防ぐ');
    });
  });
}
