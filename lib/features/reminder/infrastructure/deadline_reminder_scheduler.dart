import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';

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
class NotificationServiceDeadlineReminderScheduler
    implements DeadlineReminderScheduler {
  NotificationServiceDeadlineReminderScheduler({NotificationService? service})
      : _service = service ?? NotificationService();

  final NotificationService _service;

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
    await _service.scheduleDeadlineReminder(
      hour: s.hour,
      minute: s.minute,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel() => _service.cancelDeadlineReminder();
}
