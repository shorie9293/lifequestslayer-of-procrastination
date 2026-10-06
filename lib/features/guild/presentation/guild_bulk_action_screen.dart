// 寄合所のクエスト一括操作画面（改善提案 #91）
//
// ドメイン層 GuildBulkAction / GuildBulkActionService に全ロジックを委譲する
// 薄いプレゼンテーション層。tasksOverride / applyOverride は試練（テスト）用の注入点。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_bulk_action.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';

/// 一括操作の適用処理（試練用に差し替え可能）。適用できた件数を返す。
typedef GuildBulkApplyHandler = int Function(
    GuildBulkAction action, Set<String> ids);

class GuildBulkActionScreen extends StatefulWidget {
  const GuildBulkActionScreen({super.key, this.tasksOverride, this.applyOverride});

  /// 試練用: Provider なしでクエスト一覧を注入できる
  final List<Task>? tasksOverride;

  /// 試練用: 操作の適用を注入できる（省略時は TaskViewModel に適用）
  final GuildBulkApplyHandler? applyOverride;

  @override
  State<GuildBulkActionScreen> createState() => _GuildBulkActionScreenState();
}

class _GuildBulkActionScreenState extends State<GuildBulkActionScreen> {
  final Set<String> _selected = {};
  int _postponeDays = 1;

  static const _postponeChoices = [1, 3, 7];

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _apply(GuildBulkAction action, List<Task> tasks) {
    final plan = GuildBulkActionService.buildPlan(tasks, _selected, action);
    if (plan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対象のクエストを選択してください。')),
      );
      return;
    }
    final applied = widget.applyOverride != null
        ? widget.applyOverride!(action, Set<String>.of(plan.targetIds))
        : _applyToViewModel(action, plan.targetIds);
    setState(() => _selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${applied}件を${action.label}しました。')),
    );
  }

  int _applyToViewModel(GuildBulkAction action, List<String> ids) {
    final taskVM = context.read<TaskViewModel>();
    switch (action) {
      case GuildBulkAction.accept:
        return taskVM.acceptTasks(ids, debugMode: false);
      case GuildBulkAction.postpone:
        return taskVM.postponeTasks(ids, _postponeDays);
      case GuildBulkAction.delete:
        return taskVM.deleteTasks(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasksOverride ??
        Provider.of<TaskViewModel>(context, listen: false).guildTasks;
    final selectable = GuildBulkActionService.selectableTasks(tasks);

    return Scaffold(
      key: AppKeys.guildBulkScreen,
      appBar: AppBar(title: const Text('クエスト一括操作')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '選択: ${_selected.length}件 / 対象: ${selectable.length}件',
                    key: AppKeys.guildBulkCountLabel,
                  ),
                ),
                TextButton(
                  key: AppKeys.guildBulkSelectAll,
                  onPressed: () {
                    setState(() {
                      _selected.clear();
                      for (final t in selectable) {
                        _selected.add(t.id);
                      }
                    });
                  },
                  child: const Text('全選択'),
                ),
                TextButton(
                  key: AppKeys.guildBulkClearSelection,
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('選択解除'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('延期日数:'),
                const SizedBox(width: 8),
                for (final days in _postponeChoices)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: AppKeys.guildBulkPostponeChip(days),
                      label: Text('$days日'),
                      selected: _postponeDays == days,
                      onSelected: (_) => setState(() => _postponeDays = days),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectable.isEmpty
                ? const Center(child: Text('一括操作できるクエストがありません'))
                : ListView.builder(
                    itemCount: selectable.length,
                    itemBuilder: (context, index) {
                      final task = selectable[index];
                      return CheckboxListTile(
                        key: AppKeys.guildBulkRow(task.id),
                        value: _selected.contains(task.id),
                        onChanged: (v) => _toggle(task.id, v ?? false),
                        title: Text(task.title),
                        subtitle: Text(
                          'ランク: ${task.rank.name}'
                          '${task.deadline != null ? ' | 期限: ${_dateLabel(task.deadline!)}' : ''}',
                        ),
                        secondary: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: RankColors.forRank(task.rank),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: AppKeys.guildBulkActionAccept,
                      onPressed: () => _apply(GuildBulkAction.accept, tasks),
                      child: const Text('⚔️ 出発'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: AppKeys.guildBulkActionPostpone,
                      onPressed: () => _apply(GuildBulkAction.postpone, tasks),
                      child: const Text('📅 延期'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: AppKeys.guildBulkActionDelete,
                      onPressed: () => _apply(GuildBulkAction.delete, tasks),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('🗑 破棄'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime d) =>
      '${d.year}/${d.month}/${d.day}';
}
