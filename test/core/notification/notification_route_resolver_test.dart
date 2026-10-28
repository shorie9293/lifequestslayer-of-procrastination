import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/notification/notification_route_resolver.dart';

void main() {
  const allowed = NotificationRoutes.all;

  group('NotificationRouteResolver.resolve', () {
    test('正常なJSONを解決する（route のみ）', () {
      final route =
          NotificationRouteResolver.resolve('{"route":"guild"}', allowedRoutes: allowed);
      expect(route, isNotNull);
      expect(route!.route, 'guild');
      expect(route.id, isNull);
    });

    test('正常なJSONを解決する（id 付き）', () {
      final route = NotificationRouteResolver.resolve(
        '{"route":"guild","id":"abc"}',
        allowedRoutes: allowed,
      );
      expect(route, equals(ResolvedNotificationRoute(route: 'guild', id: 'abc')));
    });

    test('前後の空白を含む payload も解決する', () {
      final route = NotificationRouteResolver.resolve(
        '  {"route":"temple"}  ',
        allowedRoutes: allowed,
      );
      expect(route?.route, 'temple');
    });

    test('route の前後空白はトリムして解決する', () {
      final route = NotificationRouteResolver.resolve(
        '{"route":" town "}',
        allowedRoutes: allowed,
      );
      expect(route?.route, 'town');
    });

    test('未知の route は null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"unknown_screen"}',
          allowedRoutes: allowed,
        ),
        isNull,
      );
    });

    test('allowedRoutes を絞れば除外される', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"guild"}',
          allowedRoutes: const {'temple'},
        ),
        isNull,
      );
    });

    test('payload が null なら null', () {
      expect(NotificationRouteResolver.resolve(null, allowedRoutes: allowed), isNull);
    });

    test('payload が空文字・空白のみなら null', () {
      expect(NotificationRouteResolver.resolve('', allowedRoutes: allowed), isNull);
      expect(NotificationRouteResolver.resolve('   ', allowedRoutes: allowed), isNull);
    });

    test('JSONでない文字列は null', () {
      expect(
        NotificationRouteResolver.resolve('guild', allowedRoutes: allowed),
        isNull,
      );
    });

    test('壊れたJSONは null（例外を投げない）', () {
      expect(
        NotificationRouteResolver.resolve('{"route":"guild"', allowedRoutes: allowed),
        isNull,
      );
      expect(
        NotificationRouteResolver.resolve('{route:guild}', allowedRoutes: allowed),
        isNull,
      );
    });

    test('route キーが無い / 文字列でない場合は null', () {
      expect(
        NotificationRouteResolver.resolve('{"id":"abc"}', allowedRoutes: allowed),
        isNull,
      );
      expect(
        NotificationRouteResolver.resolve('{"route":123}', allowedRoutes: allowed),
        isNull,
      );
      expect(
        NotificationRouteResolver.resolve('{"route":null}', allowedRoutes: allowed),
        isNull,
      );
    });

    test('route が空文字なら null', () {
      expect(
        NotificationRouteResolver.resolve('{"route":""}', allowedRoutes: allowed),
        isNull,
      );
    });

    test('JSON配列・数値は null', () {
      expect(
        NotificationRouteResolver.resolve('["guild"]', allowedRoutes: allowed),
        isNull,
      );
      expect(NotificationRouteResolver.resolve('42', allowedRoutes: allowed), isNull);
    });

    test('id が文字列でない場合は null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"guild","id":7}',
          allowedRoutes: allowed,
        ),
        isNull,
      );
    });

    test('id が空文字なら id null として解決する', () {
      final route = NotificationRouteResolver.resolve(
        '{"route":"guild","id":""}',
        allowedRoutes: allowed,
      );
      expect(route, equals(ResolvedNotificationRoute(route: 'guild')));
    });

    test('未知のキーは無視する', () {
      final route = NotificationRouteResolver.resolve(
        '{"route":"overview","extra":"x"}',
        allowedRoutes: allowed,
      );
      expect(route?.route, 'overview');
    });
  });

  group('NotificationRouteResolver.buildPayload', () {
    test('route のみの payload を組み立てる', () {
      expect(
        NotificationRouteResolver.buildPayload('guild'),
        '{"route":"guild"}',
      );
    });

    test('id 付きの payload を組み立てる', () {
      expect(
        NotificationRouteResolver.buildPayload('guild', id: 'abc'),
        '{"route":"guild","id":"abc"}',
      );
    });

    test('buildPayload → resolve の往復で値等価になる', () {
      for (final route in NotificationRoutes.all) {
        final payload = NotificationRouteResolver.buildPayload(route, id: 'q-1');
        final resolved =
            NotificationRouteResolver.resolve(payload, allowedRoutes: allowed);
        expect(resolved, equals(ResolvedNotificationRoute(route: route, id: 'q-1')));
      }
    });

    test('空 route は ArgumentError', () {
      expect(
        () => NotificationRouteResolver.buildPayload('  '),
        throwsArgumentError,
      );
    });

    test('特殊文字を含む id も往復できる', () {
      const id = 'a/b "c" \\d';
      final payload = NotificationRouteResolver.buildPayload('guild', id: id);
      expect(
        NotificationRouteResolver.resolve(payload, allowedRoutes: allowed)?.id,
        id,
      );
    });
  });

  group('ResolvedNotificationRoute', () {
    test('値等価と hashCode', () {
      final a = ResolvedNotificationRoute(route: 'guild', id: '1');
      final b = ResolvedNotificationRoute(route: 'guild', id: '1');
      final c = ResolvedNotificationRoute(route: 'guild', id: '2');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('空 route は ArgumentError', () {
      expect(
        () => ResolvedNotificationRoute(route: ''),
        throwsArgumentError,
      );
    });
  });

  group('PendingNotificationRoute', () {
    test('保持した遷移先を1度だけ取り出せる', () {
      final holder = PendingNotificationRoute();
      final route = ResolvedNotificationRoute(route: 'guild');

      expect(holder.hasPending, isFalse);
      expect(holder.consume(), isNull);

      holder.hold(route);
      expect(holder.hasPending, isTrue);
      expect(holder.pendingRoute, equals(route));
      expect(holder.consume(), equals(route));
      expect(holder.hasPending, isFalse);
      expect(holder.consume(), isNull);
    });
  });

  group('NotificationRoutes', () {
    test('route 名は重複しない', () {
      expect(NotificationRoutes.all.length, 6);
      expect(
        NotificationRoutes.all.toSet().length,
        NotificationRoutes.all.length,
      );
    });
  });
}
