import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/overview/domain/overview_service.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

/// T11: Wizard Lv15 俯瞰の魔眼 — Overview screen with calendar and kanban views.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerVM = context.watch<PlayerViewModel>();
    final player = playerVM.player;

    if (!player.hasSkill(JobSkill.wizardOverview)) {
      return _buildLockedView(context);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('俯瞰の魔眼'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'カレンダー'),
              Tab(text: 'カンバン'),
            ],
          ),
        ),
        body: Consumer<TaskViewModel>(
          builder: (context, taskVM, _) {
            final allTasks = taskVM.tasks;
            final service = OverviewService();

            return TabBarView(
              children: [
                _CalendarView(tasks: allTasks, service: service),
                _KanbanView(tasks: allTasks, service: service),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLockedView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('俯瞰の魔眼')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[500]),
              const SizedBox(height: 16),
              Text(
                '魔導師Lv15で解放',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '「俯瞰の魔眼」スキルを習得すると、\nカレンダーとカンバンの俯瞰ビューが利用できます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarView extends StatelessWidget {
  final List<Task> tasks;
  final OverviewService service;

  const _CalendarView({required this.tasks, required this.service});

  @override
  Widget build(BuildContext context) {
    final grouped = service.groupTasksByDeadline(tasks);
    if (grouped.isEmpty) {
      return const Center(child: Text('クエストがありません'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[300],
                ),
              ),
            ),
            ...entry.value.map((task) => Card(
              child: ListTile(
                dense: true,
                title: Text(task.title, style: const TextStyle(fontSize: 14)),
                trailing: _rankBadge(task.rank),
              ),
            )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _rankBadge(QuestRank rank) {
    final (label, color) = switch (rank) {
      QuestRank.S => ('S', Colors.red[400]!),
      QuestRank.A => ('A', Colors.orange[400]!),
      QuestRank.B => ('B', Colors.blue[400]!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _KanbanView extends StatelessWidget {
  final List<Task> tasks;
  final OverviewService service;

  const _KanbanView({required this.tasks, required this.service});

  @override
  Widget build(BuildContext context) {
    final grouped = service.groupTasksByStatus(tasks);
    if (grouped.isEmpty) {
      return const Center(child: Text('クエストがありません'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          final statusLabel = switch (entry.key) {
            TaskStatus.active => '現役',
            TaskStatus.inGuild => '掲示板',
          };
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Text(statusLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${entry.value.length}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: entry.value.map((task) => Card(
                      child: ListTile(
                        dense: true,
                        title: Text(task.title,
                            style: const TextStyle(fontSize: 13)),
                        trailing: Text(
                          switch (task.rank) {
                            QuestRank.S => 'S',
                            QuestRank.A => 'A',
                            QuestRank.B => 'B',
                          },
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: switch (task.rank) {
                              QuestRank.S => Colors.red[300],
                              QuestRank.A => Colors.orange[300],
                              QuestRank.B => Colors.blue[300],
                            },
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
