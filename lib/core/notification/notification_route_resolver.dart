import 'dart:convert';

/// 通知ペイロードから解決された遷移先。
///
/// 値等価（[==] / [hashCode]）で、同一 route・id なら同一とみなす。
/// 引数検証は const にできないためコンストラクタ本体で行う。
class ResolvedNotificationRoute {
  ResolvedNotificationRoute({required this.route, this.id}) {
    if (route.trim().isEmpty) {
      throw ArgumentError.value(route, 'route', 'route must not be empty');
    }
    if (id != null && id!.isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty when provided');
    }
  }

  /// 遷移先画面を表す論理名（例: 'guild'）。
  final String route;

  /// 遷移先へ引き渡す対象ID（例: クエストID）。無ければ null。
  final String? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedNotificationRoute &&
          other.route == route &&
          other.id == id;

  @override
  int get hashCode => Object.hash(route, id);

  @override
  String toString() => 'ResolvedNotificationRoute(route: $route, id: $id)';
}

/// 通知タップの遷移先論理名（route）の正本。
///
/// 通知発火側（payload 生成）とアプリ側（画面対応表）の双方がこの定数を参照する。
abstract final class NotificationRoutes {
  static const String guild = 'guild';
  static const String temple = 'temple';
  static const String town = 'town';
  static const String overview = 'overview';
  static const String reminder = 'reminder';
  static const String settings = 'settings';

  /// 受理する route の全集合。resolver の allowedRoutes と画面対応表はこれに一致させる。
  static const Set<String> all = {
    guild,
    temple,
    town,
    overview,
    reminder,
    settings,
  };
}

/// 通知ペイロード（JSON文字列）の解釈とエンコードの正本。
///
/// 正本フォーマット: `{"route":"guild","id":"abc"}`
abstract final class NotificationRouteResolver {
  /// payload を解決する。不正（null / 空 / 破損JSON / JSONでない / 未知route）は null。
  /// 例外は投げない。
  static ResolvedNotificationRoute? resolve(
    String? payload, {
    required Set<String> allowedRoutes,
  }) {
    if (payload == null) return null;
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }

    if (decoded is! Map) return null;
    final rawRoute = decoded['route'];
    if (rawRoute is! String) return null;
    final route = rawRoute.trim();
    if (route.isEmpty) return null;
    if (!allowedRoutes.contains(route)) return null;

    final rawId = decoded['id'];
    String? id;
    if (rawId != null) {
      if (rawId is! String) return null;
      id = rawId.isEmpty ? null : rawId;
    }

    try {
      return ResolvedNotificationRoute(route: route, id: id);
    } on ArgumentError {
      return null;
    }
  }

  /// ペイロードを組み立てる（エンコードの正本）。
  static String buildPayload(String route, {String? id}) {
    if (route.trim().isEmpty) {
      throw ArgumentError.value(route, 'route', 'route must not be empty');
    }
    return jsonEncode({
      'route': route,
      if (id != null && id.isNotEmpty) 'id': id,
    });
  }
}

/// 通知タップの受け口。NotificationService が実装し、router が利用する。
abstract class NotificationRouteSource {
  /// アプリ起動前にタップされた遷移先を取り出す（1度だけ。取り出したら null に戻る）。
  ResolvedNotificationRoute? consumePendingRoute();

  /// アプリ稼働中の通知タップ通知先。
  set onRouteSelected(void Function(ResolvedNotificationRoute)? handler);
}

/// 起動前タップの遷移先を1度だけ保持する純粋なホルダー。
class PendingNotificationRoute {
  ResolvedNotificationRoute? _route;

  /// 保留中の遷移先（読み取りのみ。消費は [consume]）。
  ResolvedNotificationRoute? get pendingRoute => _route;

  bool get hasPending => _route != null;

  /// 保留中の遷移先を保持する。
  void hold(ResolvedNotificationRoute route) => _route = route;

  /// 保留中の遷移先を1度だけ取り出す。取り出したら null に戻る。
  ResolvedNotificationRoute? consume() {
    final route = _route;
    _route = null;
    return route;
  }
}
