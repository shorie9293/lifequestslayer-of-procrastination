import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_export/data/ics_share_exporter.dart';
import 'package:rpg_todo/features/calendar_export/domain/task_calendar_export_service.dart';

import 'calendar_export_keys.dart';

/// クエスト期限の iCalendar (.ics) 書き出し画面。
///
/// [tasksOverride]・[exporter]・[now] を注入でき、Provider/Hive に依存せず
/// 試練できる。本番は寄合所の⋯メニューから実タスクを渡して遷移する。
class CalendarExportScreen extends StatefulWidget {
  const CalendarExportScreen({
    super.key,
    this.tasksOverride,
    this.exporter,
    this.now,
  });

  /// 書き出し対象のクエスト。未指定時は空リスト（本番は寄合所が注入）。
  final List<Task>? tasksOverride;

  /// 共有実装。未指定時は share_plus 実装。
  final IcsShareExporter? exporter;

  /// 現在日時（試練用に固定できる）。
  final DateTime? now;

  @override
  State<CalendarExportScreen> createState() => _CalendarExportScreenState();
}

class _CalendarExportScreenState extends State<CalendarExportScreen> {
  CalendarExportRange _range = CalendarExportRange.all;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final tasks = widget.tasksOverride ?? const <Task>[];
    final selected =
        TaskCalendarExportService.selectTasks(tasks, _range, now: now);
    // 期限の無いクエストはカレンダーに載せられないため、件数・プレビューは
    // 「実際に書き出される予定」を数える（虚偽件数の防止）。
    final events = TaskCalendarExportService.buildEvents(selected);
    final preview = events.take(10);

    return Scaffold(
      key: CalendarExportAppKeys.screen,
      appBar: AppBar(
        title: const Text('カレンダー書き出し'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              key: CalendarExportAppKeys.rangeChips,
              spacing: 8,
              children: [
                for (final range in CalendarExportRange.values)
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'calendar_export_${range.name}'),
                    label: range.label,
                    child: FilterChip(
                      key: CalendarExportAppKeys.rangeChip(range),
                      label: Text(range.label),
                      selected: _range == range,
                      onSelected: (_) => setState(() => _range = range),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${events.length}件を書き出します',
              key: CalendarExportAppKeys.countLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Text(
                '書き出せるクエストがありません',
                key: CalendarExportAppKeys.emptyState,
                style: TextStyle(color: Color(0xFF888888)),
              )
            else
              Column(
                key: CalendarExportAppKeys.previewList,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final event in preview)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${_md(event.date)} ${event.summary}',
                        key: CalendarExportAppKeys.previewItem(event.uid),
                      ),
                    ),
                  if (events.length > 10)
                    Text(
                      'ほか ${events.length - 10}件',
                      style: const TextStyle(color: Color(0xFF888888)),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'calendar_export'),
                label: '書き出す',
                child: ElevatedButton.icon(
                  key: CalendarExportAppKeys.exportButton,
                  onPressed:
                      events.isEmpty || _sharing ? null : () => _share(now),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('書き出す'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(DateTime now) async {
    final exporter = widget.exporter ?? const SharePlusIcsShareExporter();
    final tasks = widget.tasksOverride ?? const <Task>[];
    final ics = TaskCalendarExportService.exportIcs(tasks, _range, now: now);
    setState(() => _sharing = true);
    try {
      await exporter.share(
        ics: ics,
        fileName: 'rpg_quests.ics',
        text: 'クエスト期限を書き出しました',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('書き出しに失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static String _md(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
