import 'package:flutter/material.dart';

import 'package:rpg_todo/core/notification/notification_route_resolver.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/overview/presentation/screens/overview_screen.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';

/// 通知タップ → 該当画面遷移の薄い配線。
///
/// ・アプリ稼働中のタップ: [NotificationRouteSource.onRouteSelected] 経由で即時遷移
/// ・アプリ起動前のタップ: [consumePendingRoute] で保留分を1度だけ取り出して遷移
/// 未知 route は何もしない（既定画面のまま）。
class NotificationTapRouter {
  NotificationTapRouter({
    required this.navigatorKey,
    required this.source,
    this.screenBuilder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final NotificationRouteSource source;

  /// 試練で差し替え可能な画面ビルダー。既定は [defaultScreenFor]。
  final Widget Function(ResolvedNotificationRoute route)? screenBuilder;

  /// resolver の allowedRoutes と画面対応表を一致させるための正本。
  static const Set<String> allowedRoutes = NotificationRoutes.all;

  /// route → 画面の対応表。
  static Widget defaultScreenFor(ResolvedNotificationRoute route) {
    switch (route.route) {
      case NotificationRoutes.guild:
        return const GuildScreen();
      case NotificationRoutes.temple:
        return const TempleScreen();
      case NotificationRoutes.town:
        return const TownScreen();
      case NotificationRoutes.overview:
        return const OverviewScreen();
      case NotificationRoutes.reminder:
        return const ReminderSettingsScreen();
      case NotificationRoutes.settings:
        return const SettingsHubScreen();
      default:
        // 未知routeは既定画面のまま（何もしない）。
        return const SizedBox.shrink();
    }
  }

  /// 通知サービスのタップ通知先を自身へ向ける。
  void attach() => source.onRouteSelected = handleRoute;

  /// アプリ起動前にタップされた保留分を1度だけ取り出して遷移する。
  void consumePendingRoute() {
    final route = source.consumePendingRoute();
    if (route == null) return;
    handleRoute(route);
  }

  /// 稼働中のタップ、または保留分の遷移実行。
  void handleRoute(ResolvedNotificationRoute route) {
    if (!allowedRoutes.contains(route.route)) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final builder = screenBuilder ?? defaultScreenFor;
    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: route.route, arguments: route.id),
        builder: (_) => builder(route),
      ),
    );
  }
}
