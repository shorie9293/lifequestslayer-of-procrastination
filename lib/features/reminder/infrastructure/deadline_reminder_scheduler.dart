import 'package:flutter/foundation.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_service.dart';

import 'quiet_hours_guard_wiring.dart';

/// 締切リマインド通知のスケジューラ抽象。
/// 画面・調整役はこの抽象にのみ依存する（試練でフェイク注入可）。
abstract class DeadlineReminderScheduler {
  Future<void> apply(
    DeadlineReminderSettings s, {
    required String title,
    required String body,
  });

  Future<void> cancel();
}

/// [NotificationService] へ処理を委譲する薄い実装。
///
/// [guard] を省略した場合は [QuietHoursGuardWiring] 経由で本番既定のガード
/// （Hive の静穏時間設定を読む [QuietHoursRepositoryGuard]）が自動的に入る。
/// guard が null を返した場合は送出しない。
class NotificationServiceDeadlineReminderScheduler
    implements DeadlineReminderScheduler {
  NotificationServiceDeadlineReminderScheduler({
    NotificationService? service,
    QuietHoursGuard? guard,
    DateTime Function()? clock,
  })  : _service = service ?? NotificationService(),
        _guard = guard ?? QuietHoursGuardWiring.create(),
        _clock = clock ?? DateTime.now;

  final NotificationService _service;
  final QuietHoursGuard _guard;
  final DateTime Function() _clock;

  @override
  Future<void> apply(
    DeadlineReminderSettings s, {
    required String title,
    required String body,
  }) async {
    if (!s.enabled) {
      await cancel();
      return;
    }
    var at = _nextOccurrence(s);
    final adjusted = await _guard.adjust(at);
    if (adjusted == null) return;
    at = adjusted;
    await scheduleAt(s, at, title: title, body: body);
  }

  DateTime _nextOccurrence(DeadlineReminderSettings s) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day, s.hour, s.minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// 実際の通知登録。試練で監視できるよう差し替え可能にしている。
  @protected
  Future<void> scheduleAt(
    DeadlineReminderSettings s,
    DateTime at, {
    required String title,
    required String body,
  }) =>
      _service.scheduleDeadlineReminder(
        hour: at.hour,
        minute: at.minute,
        title: title,
        body: body,
      );

  @override
  Future<void> cancel() => _service.cancelDeadlineReminder();
}
