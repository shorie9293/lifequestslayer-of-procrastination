import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/core/testing/tutorial_keys.dart';
import 'package:rpg_todo/features/shared/widgets/player_status_header.dart';
import 'widgets/task_card.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/features/kozuchi/presentation/widgets/kozuchi_quest_card.dart';
import 'dialogs/tutorial_reset_dialog.dart';
import 'dialogs/create_task_dialog.dart';
import 'dialogs/bulk_create_task_dialog.dart';
import 'dialogs/recurring_tasks_dialog.dart';
import 'dialogs/notification_settings_dialog.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/knowledge_quest_dialog.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  bool _isDialogOpen = false;

  Color _getRankColor(QuestRank rank) => RankColors.forRank(rank);

  void _showCreateTaskDialog(BuildContext context) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => const CreateTaskDialog(),
    ).then((_) => _isDialogOpen = false);
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(task: task),
    ).then((_) => _isDialogOpen = false);
  }

  void _acceptTask(BuildContext context, String taskId) {
    final taskVM = context.read<TaskViewModel>();
    final settingsVM = context.read<SettingsViewModel>();
    final error = taskVM.acceptTask(taskId);
    if (error == null) {
      settingsVM.completeTutorialStep(1);
      taskVM.save();
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚔️ 出発！武運を祈る！")),
      );
    }
  }

  void _deleteTask(BuildContext context, String taskId) {
    // UX-4: クエスト契約解除に確認ダイアログを追加
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("クエストを破棄"),
        content: const Text("このクエストを完全に破棄しますか？\nこの操作は取り消せません。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TaskViewModel>().deleteTask(taskId);
              context.read<TaskViewModel>().save();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("クエストを破棄しました。")),
              );
            },
            child: const Text("破棄する", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((_) => _isDialogOpen = false);
  }

  String _getTaskDetails(Task task) {
    String details = "状態: 未受注";
    if (task.repeatInterval != RepeatInterval.none) {
      details += " | 繰り返し: ${task.repeatInterval.name}";
    }
    if (task.subTasks.isNotEmpty) {
      details += " | サブクエスト: ${task.subTasks.length}個";
    }
    if (task.deadline != null) {
      final d = task.deadline!;
      details +=
          " | 期限: ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}";
    }
    return details;
  }

  /// コンパクト表示用: 難易度 + 期限 のみ（タイトルは展開時表示）
  String _getCompactTitle(Task task) {
    final rankEmoji = switch (task.rank) {
      QuestRank.S => '🐉',
      QuestRank.A => '👹',
      QuestRank.B => '👺',
    };
    final rankStr = '${rankEmoji} [${task.rank.name}]';
    if (task.deadline != null) {
      final d = task.deadline!;
      return '$rankStr  📅 ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }
    return '$rankStr  📅 期限なし';
  }

  /// 残り時間表示の文字列（日本語）を生成
  String _formatTimeRemaining(Duration diff) {
    if (diff.isNegative) {
      return '期限切れ';
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return 'あと${hours}時間${minutes > 0 ? '${minutes}分' : ''}';
    }
    if (minutes > 0) {
      return 'あと${minutes}分';
    }
    return 'まもなく締切';
  }

  /// 緊急セクションウィジェット（24時間以内の期限タスク）
  Widget _buildUrgentSection(BuildContext context, List<Task> urgentTasks) {
    return Container(
      key: AppKeys.guildUrgentSection,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFF4A0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          const Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                '緊急クエスト',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 緊急タスク一覧
          ...urgentTasks.map((task) {
            final diff = task.deadline!.difference(DateTime.now());
            final timeStr = _formatTimeRemaining(diff);
            final isExpired = diff.isNegative;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.red.shade900
                          : Colors.orange.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        color: isExpired ? Colors.redAccent : Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 🔥 緊急出撃ボタン — 戦場へ即投入
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(SemanticTypes.button, 'urgent_deploy'),
                    label: '緊急出撃：戦場へ即投入',
                    child: GestureDetector(
                      onTap: () => _acceptTask(context, task.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('⚔️', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 3),
                            Text(
                              '出発',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();
    final playerVM = context.watch<PlayerViewModel>();
    final tasks = taskVM.guildTasks;

    final now = DateTime.now();
    final urgentTasks = tasks.where((t) =>
        t.deadline != null &&
        t.deadline!.isAfter(now) &&
        t.deadline!.difference(now).inHours < 24).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("寄合所"),
        actions: [
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(SemanticTypes.button, 'bulk_create'),
            label: '一括クエスト登録',
            child: IconButton(
              icon: const Icon(Icons.post_add),
              tooltip: '一括クエスト登録',
              onPressed: () {
                if (_isDialogOpen) return;
                _isDialogOpen = true;
                showDialog(
                  context: context,
                  builder: (context) => const BulkCreateTaskDialog(),
                ).then((_) => _isDialogOpen = false);
              },
            ),
          ),
          if (playerVM.player.canUseSkill(Job.cleric))
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(SemanticTypes.button, 'recurring_tasks'),
              label: '繰り返し任務一覧',
              child: IconButton(
                icon: const Icon(Icons.loop),
                tooltip: '繰り返し任務一覧',
                onPressed: () {
                  if (_isDialogOpen) return;
                  _isDialogOpen = true;
                  showDialog(
                    context: context,
                    builder: (context) => const RecurringTasksDialog(),
                  ).then((_) => _isDialogOpen = false);
                },
              ),
            ),
          PopupMenuButton<String>(
            key: AppKeys.settingsButton,
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onSelected: (value) {
              switch (value) {
                case 'help':
                  if (_isDialogOpen) return;
                  _isDialogOpen = true;
                  showHelpDialog(context, screen: HelpScreen.guild).then((_) => _isDialogOpen = false);
                case 'notification':
                  if (_isDialogOpen) return;
                  _isDialogOpen = true;
                  showDialog(
                    context: context,
                    builder: (context) => const NotificationSettingsDialog(),
                  ).then((_) => _isDialogOpen = false);
                case 'knowledge_quest':
                  if (_isDialogOpen) return;
                  _isDialogOpen = true;
                  showDialog(
                    context: context,
                    builder: (context) => const KnowledgeQuestDialog(),
                  ).then((_) => _isDialogOpen = false);
                case 'tutorial_reset':
                  if (_isDialogOpen) return;
                  _isDialogOpen = true;
                  showDialog(
                    context: context,
                    builder: (context) => const TutorialResetDialog(),
                  ).then((_) => _isDialogOpen = false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('遊び方・ヘルプ')
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notification',
                child: Row(
                  children: [
                    Icon(Icons.notifications_none, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('通知設定')
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'knowledge_quest',
                child: Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('知識クエスト設定')
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tutorial_reset',
                child: Row(
                  children: [
                    Icon(Icons.replay, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('導きの書をリセット')
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/guild_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            const PlayerStatusHeader(),
            // ギルド未着手の見積もり合計
            if (taskVM.guildEstimatedMinutes > 0)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: Colors.black26,
                child: Row(
                  children: [
                    const Text("📋", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      "未着手のクエスト（見積もり）: ${taskVM.guildEstimatedMinutes}分",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            // Kozuchi試練セクション
            Expanded(
              child: Builder(
                builder: (context) {
                  final hasKozuchiQuest = taskVM.kozuchiQuest != null;
                  final hasUrgent = urgentTasks.isNotEmpty;
                  final remainingTasks = hasUrgent
                      ? tasks.where((t) => !urgentTasks.contains(t)).toList()
                      : tasks;
                  final itemCount = (hasKozuchiQuest ? 1 : 0) +
                      (hasUrgent ? 1 : 0) +
                      (remainingTasks.isEmpty ? 1 : remainingTasks.length);

                  return ListView.builder(
                    key: tasks.isEmpty && !hasKozuchiQuest && !hasUrgent
                        ? AppKeys.guildEmptyState
                        : AppKeys.guildQuestList,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      // Kozuchi quest card (always first if present)
                      if (hasKozuchiQuest && index == 0) {
                        return KozuchiQuestCard(
                          key: AppKeys.kozuchiSection,
                          quest: taskVM.kozuchiQuest!,
                        );
                      }

                      final kozuchiOffset = hasKozuchiQuest ? 1 : 0;

                      // Urgent section (after Kozuchi, before regular tasks)
                      if (hasUrgent && index == kozuchiOffset) {
                        return _buildUrgentSection(context, urgentTasks);
                      }

                      final urgentOffset = hasUrgent ? 1 : 0;
                      final adjustedIndex =
                          index - kozuchiOffset - urgentOffset;

                      // Empty state
                      if (remainingTasks.isEmpty) {
                        return SemanticHelper.container(
                          testId: SemanticHelper.createTestId(
                              SemanticTypes.section, 'empty_no_quests'),
                          label: 'クエストなし',
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("🏯", style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text(
                                  "まだクエストが届いていない。",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "右下の ＋ から最初のクエストを登録しよう！",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Task card (非緊急: コンパクト表示)
                      final task = remainingTasks[adjustedIndex];
                      return SemanticHelper.listItem(
                        testId: SemanticHelper.createTestId(
                            SemanticTypes.listItem, 'task_$adjustedIndex'),
                        index: adjustedIndex,
                        child: TaskCard(
                          task: task,
                          color: _getRankColor(task.rank),
                          titleOverride: _getCompactTitle(task),
                          hideCountdown: true,
                          expandedDetails: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '[${task.rank.name}] ${task.title}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (task.targetTimeMinutes != null)
                                Text(
                                  '⏱ 見積もり: ${task.targetTimeMinutes}分',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              Text(
                                _getTaskDetails(task),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            SemanticHelper.interactive(
                              testId: SemanticHelper.createTestId(SemanticTypes.button, 'edit_task'),
                              label: 'クエストを編集',
                              child: TextButton(
                                onPressed: () =>
                                    _showEditTaskDialog(context, task),
                                child: const Text("編集",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                            SemanticHelper.interactive(
                              testId: SemanticHelper.createTestId(SemanticTypes.button, 'delete_task'),
                              label: 'クエストを破棄',
                              child: TextButton(
                                key: AppKeys.taskCardDelete,
                                onPressed: () => _deleteTask(context, task.id),
                                child: const Text("破棄",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SemanticHelper.interactive(
                              testId: SemanticHelper.createTestId(SemanticTypes.button, 'accept_task'),
                              label: 'クエストを受注して出発',
                              child: ElevatedButton(
                                key: adjustedIndex == 0
                                    ? TutorialKeys.acceptTaskKey
                                    : null,
                                onPressed: () =>
                                    _acceptTask(context, task.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                child: const Text("出発する"),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(SemanticTypes.button, 'add_task'),
        hint: '新規クエストを登録',
        child: FloatingActionButton(
          key: TutorialKeys.fabKey,
          onPressed: () => _showCreateTaskDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
