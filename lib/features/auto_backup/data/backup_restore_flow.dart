import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_coordinator.dart';

/// 復元後に通知予約を貼り直す本番実装。
///
/// 起動時（lib/main.dart）と同じ2手を踏む:
///   1. [NotificationService.scheduleAll] — 朝/夕の定時通知
///   2. [DeadlineReminderCoordinator.run] — 期限間近クエストの通知
///
/// 復元で notification_settings の時刻が巻き戻ると、既存予約は古い時刻のまま
/// 残る。ここで貼り直さないと「復元したのに鳴らない」状態になる。
///
/// 例外はすべてここで握る（復元結果を壊さない）。
Future<void> rescheduleNotificationsAfterRestore() async {
  try {
    await NotificationService().scheduleAll();
  } catch (_) {
    // 通知基盤が使えない環境（試練・未初期化）でも復元は成功させる。
  }
  try {
    await DeadlineReminderCoordinator().run();
  } catch (_) {
    // 同上。
  }
}

/// 自動バックアップ JSON を現世へ適用する（復元の実体）。
///
/// [onRestored] は復元成功後に**1回だけ** await される注入口。本番は
/// [rescheduleNotificationsAfterRestore] を投げっぱなしで渡す。
/// その例外は握り、復元の成否には影響させない。
Future<void> applyBackupJson({
  required String json,
  required void Function(Player player) restorePlayer,
  required void Function(List<Task> tasks) setTasks,
  required Future<void> Function(Map<String, Map<String, dynamic>> boxes)
      restoreBoxes,
  Future<void> Function()? onRestored,
}) async {
  final data = FullBackupService().decode(json);
  if (data == null) {
    throw const FormatException('バックアップ形式が不正です');
  }
  restorePlayer(data.player);
  setTasks(data.tasks);
  await restoreBoxes(data.boxes);
  if (onRestored != null) {
    try {
      await onRestored();
    } catch (_) {
      // 付随処理の失敗で復元結果を反転させない。
    }
  }
}
