import 'package:flutter/material.dart';

import '../../../core/testing/widget_keys.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder_schedule_service.dart';
import '../domain/reminder_settings.dart';
import '../infrastructure/reminder_scheduler.dart';

/// 勤行リマインダーの設定画面。
///
/// リポジトリ・スケジューラ・現在時刻は注入可能（試練でフェイクを差し込む）。
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({
    super.key,
    ReminderRepository? repository,
    ReminderScheduler? scheduler,
    DateTime? now,
  })  : _repository = repository,
        _scheduler = scheduler,
        _now = now;

  final ReminderRepository? _repository;
  final ReminderScheduler? _scheduler;
  final DateTime? _now;

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  static const _weekdayKanji = ['月', '火', '水', '木', '金', '土', '日'];

  late final ReminderRepository _repository =
      widget._repository ?? HiveReminderRepository();
  late final ReminderScheduler _scheduler =
      widget._scheduler ?? NotificationServiceReminderScheduler();
  final ReminderScheduleService _service = const ReminderScheduleService();

  bool _loaded = false;
  ReminderSettings _settings = ReminderSettings.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
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

  void _toggleWeekday(int weekday) {
    final current = List<int>.of(_settings.weekdays);
    if (current.contains(weekday)) {
      current.remove(weekday);
    } else {
      current.add(weekday);
      current.sort();
    }
    setState(() => _settings = _settings.copyWith(weekdays: current));
  }

  Future<void> _save() async {
    await _repository.save(_settings);
    await _scheduler.apply(_settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('勤行リマインダーを保存しました')),
    );
  }

  String _previewText() {
    final now = widget._now ?? DateTime.now();
    final next = _service.nextOccurrence(_settings, now);
    if (next == null) return '通知は設定されていません';
    const months = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ];
    final dateLabel =
        '${months[next.month - 1]}${next.day}日(${_weekdayKanji[next.weekday - 1]})';
    return '次の通知: ${_service.weekdayLabel(_settings.weekdays)} '
        '${_service.timeLabel(_settings.hour, _settings.minute)} → '
        '$dateLabel ${_service.timeLabel(next.hour, next.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      key: AppKeys.reminderSettingsScreen,
      title: const Text('勤行リマインダー'),
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
            key: AppKeys.reminderEnabledSwitch,
            title: const Text('勤行リマインダー'),
            subtitle: const Text('選択した曜日の勤行の時刻に通知します'),
            value: enabled,
            onChanged: (v) =>
                setState(() => _settings = _settings.copyWith(enabled: v)),
          ),
          if (enabled) ...[
            ListTile(
              key: AppKeys.reminderTimePicker,
              title: const Text('通知時刻'),
              trailing: Text(
                _service.timeLabel(_settings.hour, _settings.minute),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var w = 1; w <= 7; w++)
                  FilterChip(
                    key: AppKeys.reminderWeekdayChip(w),
                    label: Text(_weekdayKanji[w - 1]),
                    selected: _settings.weekdays.contains(w),
                    onSelected: (_) => _toggleWeekday(w),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _previewText(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: AppKeys.reminderSaveButton,
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
