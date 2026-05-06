import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/core/testing/tutorial_keys.dart';
import 'package:rpg_todo/features/shared/widgets/player_status_header.dart';
import 'widgets/task_card.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'dialogs/tutorial_reset_dialog.dart';
import 'dialogs/create_task_dialog.dart';
import 'dialogs/recurring_tasks_dialog.dart';
import 'dialogs/notification_settings_dialog.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/knowledge_quest_dialog.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  Color _getRankColor(QuestRank rank) => RankColors.forRank(rank);

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateTaskDialog(),
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(task: task),
    );
  }

  void _acceptTask(BuildContext context, String taskId) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    final error = viewModel.acceptTask(taskId);
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
    Provider.of<GameViewModel>(context, listen: false).deleteTask(taskId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("クエストを破棄しました。")),
    );
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

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.guildTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("冒険者ギルド"),
        actions: [
          if (viewModel.player.canUseSkill(Job.cleric))
            IconButton(
              icon: const Icon(Icons.loop),
              tooltip: '繰り返し任務一覧',
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const RecurringTasksDialog(),
              ),
            ),
          PopupMenuButton<String>(
            key: AppKeys.settingsButton,
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onSelected: (value) {
              switch (value) {
                case 'help':
                  showHelpDialog(context);
                case 'notification':
                  showDialog(
                    context: context,
                    builder: (context) => const NotificationSettingsDialog(),
                  );
                case 'knowledge_quest':
                  showDialog(
                    context: context,
                    builder: (context) => const KnowledgeQuestDialog(),
                  );
                case 'tutorial_reset':
                  showDialog(
                    context: context,
                    builder: (context) => const TutorialResetDialog(),
                  );
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
                    Text('チュートリアルをリセット')
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
            if (viewModel.guildEstimatedMinutes > 0)
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
                      "未着手の依頼（見積もり）: ${viewModel.guildEstimatedMinutes}分",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: tasks.isEmpty
                  ? SemanticHelper.container(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.section, 'empty_no_quests'),
                      label: 'クエストなし',
                      child: const SingleChildScrollView(
                        key: AppKeys.guildEmptyState,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("🏰", style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text(
                                "まだクエストが届いていない。",
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "右下の ＋ から最初のクエストを登録しよう！",
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: AppKeys.guildQuestList,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return SemanticHelper.listItem(
                          testId: SemanticHelper.createTestId(
                              SemanticTypes.listItem, 'task_$index'),
                          index: index,
                          child: TaskCard(
                            task: task,
                            color: _getRankColor(task.rank),
                            subtitle: _getTaskDetails(task),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    _showEditTaskDialog(context, task),
                                child: const Text("編集",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                key: AppKeys.taskCardDelete,
                                onPressed: () => _deleteTask(context, task.id),
                                child: const Text("破棄",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                key: index == 0
                                    ? TutorialKeys.acceptTaskKey
                                    : null,
                                onPressed: () => _acceptTask(context, task.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                child: const Text("出発する"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(SemanticTypes.button, 'add_task'),
        hint: '新規クエストを作成',
        child: FloatingActionButton(
          key: TutorialKeys.fabKey,
          onPressed: () => _showCreateTaskDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
