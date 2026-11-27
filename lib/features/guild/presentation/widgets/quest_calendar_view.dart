// 寄合所のカレンダー表示。
//
// 月のマス目にクエストの期限を並べる。マスをタップするとその日の
// クエストが下から出る（一覧画面へ遷移しないので、月を見たまま確認できる）。
//
// 日付の計算は行わない（全て domain/quest_calendar.dart の純粋関数）。
// ここは「描く・押す・送る」だけを受け持つ。

import 'package:flutter/material.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_calendar.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

const List<String> _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

/// カレンダー表示（月送り・日別シート付き）。
class QuestCalendarView extends StatefulWidget {
  const QuestCalendarView({
    super.key,
    required this.tasks,
    this.now,
    this.onTaskTap,
  });

  final List<Task> tasks;

  /// 「今日」の判定に使う時刻。試練では固定値を注入する。
  final DateTime? now;

  /// マス内ではなく日別シートからクエストを開くときの通知（任意）。
  final void Function(Task task)? onTaskTap;

  @override
  State<QuestCalendarView> createState() => _QuestCalendarViewState();
}

class _QuestCalendarViewState extends State<QuestCalendarView> {
  late DateTime _month;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = DateTime(_now.year, _now.month, 1);
  }

  void _moveMonth(int delta) {
    setState(() => _month = addMonths(_month, delta));
  }

  void _goToday() {
    setState(() => _month = DateTime(_now.year, _now.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final calendar =
        buildQuestCalendar(month: _month, tasks: widget.tasks);
    final today = dateOnly(_now);

    return Column(
      key: AppKeys.questCalendarView,
      children: [
        _header(palette, calendar),
        _weekdayRow(palette),
        Expanded(
          // マスの高さは固定（画面の高さに依存させない）。
          // 可変にすると横向き・小画面で中身が溢れる。
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final week in calendar.weeks)
                  Row(
                    children: [
                      for (final cell in week)
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: _dayCell(context, palette, cell, today),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (calendar.undated.isNotEmpty)
          _undatedRow(context, palette, calendar.undated),
      ],
    );
  }

  Widget _header(GamePalette palette, QuestCalendarMonth calendar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: AppKeys.questCalendarPrevMonth,
            icon: const Icon(Icons.chevron_left),
            tooltip: '前の月',
            onPressed: () => _moveMonth(-1),
          ),
          Expanded(
            child: Text(
              calendar.label,
              key: AppKeys.questCalendarLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
              ),
            ),
          ),
          IconButton(
            key: AppKeys.questCalendarNextMonth,
            icon: const Icon(Icons.chevron_right),
            tooltip: '次の月',
            onPressed: () => _moveMonth(1),
          ),
          TextButton(
            key: AppKeys.questCalendarToday,
            onPressed: _goToday,
            child: Text('今日', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );
  }

  Widget _weekdayRow(GamePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          for (final label in _weekdayLabels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: palette.onSurfaceFaint),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    GamePalette palette,
    QuestCalendarCell cell,
    DateTime today,
  ) {
    final isToday = cell.date == today;
    final isPast = cell.date.isBefore(today);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(
            SemanticTypes.button, 'quest_calendar_${cell.id}'),
        label: '${cell.date.month}月${cell.date.day}日 ${cell.count}件',
        child: InkWell(
          key: AppKeys.questCalendarCell(cell.id),
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openDay(context, palette, cell),
          child: Container(
            decoration: BoxDecoration(
              color: cell.inMonth ? palette.cardBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isToday ? palette.accent : palette.border,
                width: isToday ? 1.5 : 0.5,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cell.date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: !cell.inMonth
                        ? palette.onSurfaceFaintest
                        : isPast
                            ? palette.onSurfaceFaint
                            : palette.onSurface,
                  ),
                ),
                if (cell.count > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final task in cell.tasks.take(3))
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: BoxDecoration(
                            color: RankColors.forRank(task.rank),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (cell.count > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            '+${cell.count - 3}',
                            style: TextStyle(
                              fontSize: 8,
                              color: palette.onSurfaceFaint,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _undatedRow(
      BuildContext context, GamePalette palette, List<Task> undated) {
    return InkWell(
      key: AppKeys.questCalendarUndatedRow,
      onTap: () => _openDay(
        context,
        palette,
        QuestCalendarCell(
          date: dateOnly(_now),
          inMonth: true,
          tasks: undated,
        ),
        title: '期限のないクエスト',
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: palette.cardBackground,
        child: Text(
          '期限のないクエスト: ${undated.length}件',
          style: TextStyle(fontSize: 12, color: palette.onSurfaceMuted),
        ),
      ),
    );
  }

  /// その日のクエストを下から出す。
  void _openDay(
    BuildContext context,
    GamePalette palette,
    QuestCalendarCell cell, {
    String? title,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.cardBackgroundStrong,
      builder: (sheetContext) {
        final sheetPalette = GamePalette.of(sheetContext);
        return SafeArea(
          key: AppKeys.questCalendarDaySheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  title ??
                      '${cell.date.month}月${cell.date.day}日のクエスト'
                          '（${cell.count}件）',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: sheetPalette.onSurface,
                  ),
                ),
              ),
              if (cell.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Text(
                    'この日の期限はありません。',
                    style: TextStyle(
                        fontSize: 13, color: sheetPalette.onSurfaceFaint),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cell.tasks.length,
                    itemBuilder: (_, index) {
                      final task = cell.tasks[index];
                      return ListTile(
                        key: AppKeys.questCalendarTaskRow(task.id),
                        dense: true,
                        leading: Text(
                          task.rank.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: RankColors.forRank(task.rank),
                          ),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                              fontSize: 14, color: sheetPalette.onSurface),
                        ),
                        subtitle: task.status == TaskStatus.active
                            ? Text(
                                '受注中',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: sheetPalette.onSurfaceFaint),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          widget.onTaskTap?.call(task);
                        },
                      );
                    },
                  ),
                ),
              if (cell.isEmpty)
                const SizedBox(height: 4)
              else
                const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
