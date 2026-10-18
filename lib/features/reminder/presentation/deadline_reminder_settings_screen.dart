import 'package:flutter/material.dart';

import '../../../core/testing/widget_keys.dart';
import '../../../domain/models/task.dart';
import '../../guild/data/task_repository.dart';
import '../data/deadline_reminder_repository.dart';
import '../domain/deadline_reminder_service.dart';
import '../domain/deadline_reminder_settings.dart';
import '../infrastructure/deadline_reminder_scheduler.dart';

/// 締切リマインド（期限間近クエストの通知）の設定画面。
///
/// 勤行リマインダーとは独立した設定・独立した永続キーを持つ。
/// リポジトリ・スケジューラ・クエスト一覧・現在時刻はすべて注入可能
/// （試練で Hive に触れずに検証できるようにするため）。
class DeadlineReminderSettingsScreen extends StatefulWidget {
  const DeadlineReminderSettingsScreen({
    super.key,
    DeadlineReminderRepository? repository,
    DeadlineReminderScheduler? scheduler,
    List<Task>? tasksOverride,
    Future<List<Task>> Function()? taskLoader,
    DateTime? now,
  })  : _repository = repository,
        _scheduler = scheduler,
        _tasksOverride = tasksOverride,
        _taskLoader = taskLoader,
        _now = now;

  final DeadlineReminderRepository? _repository;
  final DeadlineReminderScheduler? _scheduler;
  final List<Task>? _tasksOverride;
  final Future<List<Task>> Function()? _taskLoader;
  final DateTime? _now;

  @override
  State<DeadlineReminderSettingsScreen> createState() =>
      _DeadlineReminderSettingsScreenState();
}

class _DeadlineReminderSettingsScreenState
    extends State<DeadlineReminderSettingsScreen> {
  late final DeadlineReminderRepository _repository =
      widget._repository ?? HiveDeadlineReminderRepository();
  late final DeadlineReminderScheduler _scheduler =
      widget._scheduler ?? NotificationServiceDeadlineReminderScheduler();
  final DeadlineReminderService _service = const DeadlineReminderService();

  bool _loaded = false;
  DeadlineReminderSettings _settings = DeadlineReminderSettings.defaults();
  List<Task> _tasks = const [];

  DateTime get _now => widget._now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    List<Task> tasks;
    if (widget._tasksOverride != null) {
      tasks = widget._tasksOverride!;
    } else {
      try {
        final loader = widget._taskLoader ?? (() => TaskRepository().loadTasks());
        tasks = await loader();
      } catch (_) {
        // クエスト読込に失敗しても設定画面は壊さない（対象0件として扱う）。
        tasks = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _tasks = tasks;
      _loaded = true;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
    );
    if (picked == null) return;
    setState(() {
      _settings = _settings.copyWith(hour: picked.hour, minute: picked.minute);
    });
  }

  List<Task> _selected() => _service.selectUpcoming(
        _tasks,
        _now,
        withinDays: _settings.withinDays,
      );

  Future<void> _save() async {
    final saved = _settings.copyWith(updatedAt: _now);
    await _repository.save(saved);
    final selected = _service.selectUpcoming(
      _tasks,
      _now,
      withinDays: saved.withinDays,
    );
    final body = _service.buildBody(selected, _now);
    String message;
    if (!saved.enabled) {
      await _scheduler.cancel();
      message = '締切リマインドを停止しました';
    } else if (body == null) {
      await _scheduler.cancel();
      message = '対象期間内に締切のクエストが無いため通知は解除されました';
    } else {
      await _scheduler.apply(
        saved,
        title: _service.buildTitle(selected.length),
        body: body,
      );
      message = '締切リマインドを保存しました（対象${selected.length}件）';
    }
    if (!mounted) return;
    setState(() => _settings = saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      key: AppKeys.deadlineReminderSettingsScreen,
      title: const Text('締切リマインド'),
    );
    if (!_loaded) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final enabled = _settings.enabled;
    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: AppKeys.deadlineReminderEnabledSwitch,
            title: const Text('締切リマインド'),
            subtitle: const Text('期限が近いクエストを毎日決まった時刻に知らせます'),
            value: enabled,
            onChanged: (v) =>
                setState(() => _settings = _settings.copyWith(enabled: v)),
          ),
          if (enabled) ...[
            ListTile(
              key: AppKeys.deadlineReminderTimePicker,
              title: const Text('通知時刻'),
              trailing: Text(
                _service.timeLabel(_settings.hour, _settings.minute),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Text('期限間近とみなす範囲', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final days in const [1, 3, 7])
                  ChoiceChip(
                    key: AppKeys.deadlineReminderWithinChip(days),
                    label: Text(days == 1 ? '当日のみ' : '$days日以内'),
                    selected: _settings.withinDays == days,
                    onSelected: (_) => setState(
                      () => _settings = _settings.copyWith(withinDays: days),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _service.previewLabel(_selected(), _now),
            key: AppKeys.deadlineReminderPreview,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: AppKeys.deadlineReminderSaveButton,
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
