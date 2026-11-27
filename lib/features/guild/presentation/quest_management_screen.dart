// クエスト管理ハブ（寄合所の ⋯ から入る第2層の画面）。
//
// 2026-11-28: 寄合所の右上に入口が19個まで増え、日常動線（今日どれをやるか）が
// 埋もれていた。溢れメニューの13項目を「作る／ふりかえる／カレンダー／しらせる」の
// 4節へまとめ、寄合所の⋯はこの1画面への入口にした（1機能1入口）。
//
// 各項目のキーは移設前と同一（既存の試練・自動化がそのまま辿れる）。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_screen.dart';
import 'package:rpg_todo/features/calendar_link/presentation/calendar_import_screen.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/bulk_create_task_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/recurring_tasks_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_keys.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_screen.dart';
import 'package:rpg_todo/features/guild/presentation/quest_streak_keys.dart'
    as q;
import 'package:rpg_todo/features/guild/presentation/quest_streak_screen.dart';
import 'package:rpg_todo/features/guild/presentation/task_template_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/habits/presentation/screens/habit_calendar_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';

/// 勤行リマインダー画面から静穏時間画面への導線（本番結線）。
Widget _buildQuietHoursScreen(BuildContext context) =>
    const QuietHoursSettingsScreen();

/// クエスト管理ハブ。
class QuestManagementScreen extends StatefulWidget {
  const QuestManagementScreen({super.key, this.taskTemplateRepository});

  /// 定型の保存先（試練での注入用。未指定なら DI か メモリ実装）。
  final TaskTemplateRepository? taskTemplateRepository;

  @override
  State<QuestManagementScreen> createState() => _QuestManagementScreenState();
}

class _QuestManagementScreenState extends State<QuestManagementScreen> {
  bool _isDialogOpen = false;

  void _openTemplate() {
    final repo = widget.taskTemplateRepository ??
        (getIt.isRegistered<TaskTemplateRepository>()
            ? getIt<TaskTemplateRepository>()
            : InMemoryTaskTemplateRepository());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskTemplateScreen(
          repository: repo,
          onTaskCreated: (task) {
            if (!context.mounted) return;
            context.read<GameViewModel>().addTask(
                  task.title,
                  rank: task.rank,
                  repeatInterval: task.repeatInterval,
                  repeatWeekdays:
                      task.repeatWeekdays.isEmpty ? null : task.repeatWeekdays,
                  subTasks: task.subTasks.isEmpty ? null : task.subTasks,
                  targetTimeMinutes: task.targetTimeMinutes,
                );
          },
        ),
      ),
    );
  }

  Future<void> _openBulkCreate() async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => const BulkCreateTaskDialog(),
    );
    _isDialogOpen = false;
  }

  Future<void> _openRecurring() async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (_) => const RecurringTasksDialog(),
    );
    _isDialogOpen = false;
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final player = context.watch<PlayerViewModel>().player;
    final taskVM = context.watch<TaskViewModel>();

    return Scaffold(
      key: AppKeys.questManagementScreen,
      appBar: AppBar(title: const Text('クエスト管理')),
      // 件数は10件程度なので、遅延構築の ListView ではなく Column で全部組む。
      // （遅延構築だと画面外の項目が存在せず、支援技術・自動操作から辿れない）
      body: SingleChildScrollView(
        child: Column(
          children: [
            _sectionLabel(palette, 'つくる'),
            ListTile(
              key: AppKeys.taskTemplateEntry,
              leading: const Icon(Icons.bookmark_border,
                  key: AppKeys.guildOverflowTaskTemplate),
              title: const Text('勤行の定型'),
              subtitle: const Text('よく作るクエストを定型から一括で起こす'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openTemplate,
            ),
            ListTile(
              key: AppKeys.guildOverflowBulkCreate,
              leading: const Icon(Icons.post_add),
              title: const Text('一括クエスト登録'),
              subtitle: const Text('複数行のテキストからまとめて登録する'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openBulkCreate,
            ),
            if (player.canUseSkill(Job.monk))
              ListTile(
                key: AppKeys.guildOverflowRecurringTasks,
                leading: const Icon(Icons.loop),
                title: const Text('繰り返し任務一覧'),
                subtitle: const Text('毎日・毎週の任務をまとめて確認する'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openRecurring,
              ),
            _sectionLabel(palette, 'ふりかえる'),
            ListTile(
              key: AppKeys.habitCalendarEntry,
              leading: const Icon(Icons.calendar_month,
                  key: AppKeys.guildOverflowHabitCalendar),
              title: const Text('勤行の習慣カレンダー'),
              subtitle: const Text('毎日の勤行が続いているかを見る'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(const HabitCalendarScreen()),
            ),
            ListTile(
              key: EstimateAccuracyKeys.guildEntry,
              leading: const Icon(Icons.insights),
              title: const Text('見積もり精度レポート'),
              subtitle: const Text('見積もりと実績のずれを確かめる'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(const EstimateAccuracyScreen()),
            ),
            ListTile(
              key: q.QuestStreakKeys.guildEntry,
              leading: const Icon(Icons.local_fire_department,
                  key: AppKeys.guildOverflowQuestStreak),
              title: const Text('クエスト別ストリーク'),
              subtitle: const Text('クエストごとの連続討伐日数'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(const QuestStreakScreen()),
            ),
            _sectionLabel(palette, 'カレンダー'),
            ListTile(
              key: AppKeys.guildCalendarExportEntry,
              leading: const Icon(Icons.event_available),
              title: const Text('カレンダー書き出し'),
              subtitle: const Text('期限を .ics で他のカレンダーアプリへ渡す'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(
                CalendarExportScreen(tasksOverride: taskVM.guildTasks),
              ),
            ),
            ListTile(
              key: AppKeys.guildCalendarImportEntry,
              leading: const Icon(Icons.event_note),
              title: const Text('カレンダーから取り込む'),
              subtitle: const Text('端末カレンダーの予定をクエストにする'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(
                CalendarImportScreen(
                  tasksOverride: taskVM.guildTasks,
                  onImport: taskVM.addImportedTasks,
                ),
              ),
            ),
            _sectionLabel(palette, 'しらせる'),
            ListTile(
              key: AppKeys.reminderSettingsEntry,
              leading:
                  const Icon(Icons.alarm, key: AppKeys.guildOverflowReminder),
              title: const Text('勤行リマインダー'),
              subtitle: const Text('通知の時刻・曜日・静穏時間'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(
                const ReminderSettingsScreen(
                  quietHoursScreenBuilder: _buildQuietHoursScreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(GamePalette palette, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: palette.onSurfaceFaint,
            letterSpacing: 1.2,
          ),
        ),
      );
}
