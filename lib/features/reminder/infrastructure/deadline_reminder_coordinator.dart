import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/features/reminder/data/deadline_reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_service.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_scheduler.dart';

/// 調整役の結果。
enum DeadlineReminderOutcome {
  /// 通知をスケジュールした。
  scheduled,

  /// 設定が無効のため解除した。
  canceledDisabled,

  /// 対象クエストが無いため解除した。
  canceledEmpty,
}

/// 起動時などに「設定を読む → クエストを読む → 本文を組む → 通知へ反映」を
/// 一括で行う調整役。全依存を注入可能（試練でフェイクを差し込む）。
class DeadlineReminderCoordinator {
  DeadlineReminderCoordinator({
    DeadlineReminderRepository? repository,
    DeadlineReminderScheduler? scheduler,
    Future<List<Task>> Function()? taskLoader,
    DateTime Function()? clock,
    DeadlineReminderService service = const DeadlineReminderService(),
  })  : _repository = repository ?? HiveDeadlineReminderRepository(),
        _scheduler = scheduler ?? NotificationServiceDeadlineReminderScheduler(),
        _taskLoader = taskLoader ?? (() => TaskRepository().loadTasks()),
        _clock = clock ?? DateTime.now,
        _service = service;

  final DeadlineReminderRepository _repository;
  final DeadlineReminderScheduler _scheduler;
  final Future<List<Task>> Function() _taskLoader;
  final DateTime Function() _clock;
  final DeadlineReminderService _service;

  Future<DeadlineReminderOutcome> run() async {
    final settings = await _repository.load();
    if (!settings.enabled) {
      await _scheduler.cancel();
      return DeadlineReminderOutcome.canceledDisabled;
    }
    final tasks = await _taskLoader();
    final now = _clock();
    final selected = _service.selectUpcoming(
      tasks,
      now,
      withinDays: settings.withinDays,
    );
    final body = _service.buildBody(selected, now);
    if (body == null) {
      await _scheduler.cancel();
      return DeadlineReminderOutcome.canceledEmpty;
    }
    await _scheduler.apply(
      settings,
      title: _service.buildTitle(selected.length),
      body: body,
    );
    return DeadlineReminderOutcome.scheduled;
  }

  /// 画面側と同じ本文を組み立てるための公開ヘルパ
  /// （通知本文が画面プレビューと一致することを試練で撃てるようにする）。
  String? bodyFor(
    List<Task> tasks,
    DeadlineReminderSettings settings,
    DateTime now,
  ) {
    final selected = _service.selectUpcoming(
      tasks,
      now,
      withinDays: settings.withinDays,
    );
    return _service.buildBody(selected, now);
  }
}
