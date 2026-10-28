import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/notification/notification_route_resolver.dart';
import 'package:rpg_todo/core/notification/notification_tap_router.dart';

/// プラグイン初期化を伴わない、純粋な NotificationRouteSource のフェイク。
class _FakeRouteSource implements NotificationRouteSource {
  final PendingNotificationRoute _pending = PendingNotificationRoute();
  void Function(ResolvedNotificationRoute)? handler;

  @override
  set onRouteSelected(void Function(ResolvedNotificationRoute)? value) {
    handler = value;
  }

  @override
  ResolvedNotificationRoute? consumePendingRoute() => _pending.consume();

  void hold(ResolvedNotificationRoute route) => _pending.hold(route);
}

class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late _FakeRouteSource source;
  late _RecordingObserver observer;

  NotificationTapRouter buildRouter() => NotificationTapRouter(
        navigatorKey: navigatorKey,
        source: source,
        // 実画面は Provider/Hive 依存のため、試練では軽量スタブに差し替える。
        screenBuilder: (route) => Scaffold(
          body: Center(child: Text('route:${route.route}')),
        ),
      );

  Future<void> pumpApp(WidgetTester tester) async {
    navigatorKey = GlobalKey<NavigatorState>();
    source = _FakeRouteSource();
    observer = _RecordingObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    );
  }

  group('NotificationTapRouter', () {
    testWidgets('route 指定で Navigator に push される', (tester) async {
      await pumpApp(tester);
      final router = buildRouter();

      router.handleRoute(ResolvedNotificationRoute(route: 'guild', id: 'q1'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, 2); // home + push
      expect(find.text('route:guild'), findsOneWidget);
      expect(
        observer.pushed.last.settings.name,
        'guild',
      );
      expect(observer.pushed.last.settings.arguments, 'q1');
    });

    testWidgets('allowedRoutes 外の route では push されない', (tester) async {
      await pumpApp(tester);
      final router = buildRouter();

      router.handleRoute(ResolvedNotificationRoute(route: 'nope'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, 1); // home のみ
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('pending は1度だけ消費される（2回目は遷移しない）', (tester) async {
      await pumpApp(tester);
      final router = buildRouter();
      source.hold(ResolvedNotificationRoute(route: 'temple'));

      router.consumePendingRoute();
      await tester.pumpAndSettle();
      expect(observer.pushed.length, 2);
      expect(find.text('route:temple'), findsOneWidget);

      router.consumePendingRoute();
      await tester.pumpAndSettle();
      expect(observer.pushed.length, 2); // 追加遷移なし
    });

    testWidgets('pending が無ければ何もしない', (tester) async {
      await pumpApp(tester);
      final router = buildRouter();

      router.consumePendingRoute();
      await tester.pumpAndSettle();

      expect(observer.pushed.length, 1);
    });

    testWidgets('attach() 後は onRouteSelected 経由のタップで push される',
        (tester) async {
      await pumpApp(tester);
      final router = buildRouter();

      router.attach();
      expect(source.handler, isNotNull);

      source.handler!(ResolvedNotificationRoute(route: 'town'));
      await tester.pumpAndSettle();

      expect(observer.pushed.length, 2);
      expect(find.text('route:town'), findsOneWidget);
    });

    testWidgets('navigator 未生成時は例外を投げず何もしない', (tester) async {
      navigatorKey = GlobalKey<NavigatorState>();
      source = _FakeRouteSource();
      final router = buildRouter();

      expect(
        () => router.handleRoute(ResolvedNotificationRoute(route: 'guild')),
        returnsNormally,
      );
    });

    test('対応表のキーは allowedRoutes と一致し、全 route に画面がある', () {
      expect(NotificationTapRouter.allowedRoutes, NotificationRoutes.all);
      expect(NotificationTapRouter.allowedRoutes.length, 6);
      for (final route in NotificationRoutes.all) {
        final screen = NotificationTapRouter.defaultScreenFor(
          ResolvedNotificationRoute(route: route),
        );
        expect(
          screen,
          isNot(isA<SizedBox>()),
          reason: '$route の画面対応が欠けている',
        );
      }
    });
  });
}
