import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';

/// 通知スケジューラの抽象。画面はこの抽象にのみ依存する（テストでフェイク注入可）。
abstract class ReminderScheduler {
  Future<void> apply(ReminderSettings s);
  Future<void> cancel();
}

/// [NotificationService] へ処理を委譲する薄い実装。
class NotificationServiceReminderScheduler implements ReminderScheduler {
  NotificationServiceReminderScheduler({NotificationService? service})
      : _service = service ?? NotificationService();

  final NotificationService _service;

  @override
  Future<void> apply(ReminderSettings s) async {
    if (!s.enabled) {
      await cancel();
      return;
    }
    await _service.schedulePracticeReminder(
      hour: s.hour,
      minute: s.minute,
      weekdays: s.weekdays,
    );
  }

  @override
  Future<void> cancel() => _service.cancelPracticeReminder();
}
