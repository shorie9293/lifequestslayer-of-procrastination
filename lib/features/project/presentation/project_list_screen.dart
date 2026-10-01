// 計画の陣（プロジェクト一覧）画面 — Mystic Lv10「計画の陣」
//
// プロジェクト一覧・作成・編集・削除・クエスト割り当て/解除。
// 純粋ロジックは ProjectService、状態変更は PlayerViewModel。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/project/domain/project_service.dart';
import 'package:rpg_todo/features/project/presentation/project_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// プロジェクト一覧画面。
///
/// [playerOverride] / [tasksOverride] を与えると provider に依存せず
/// 試練（headless）が通る。
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key, this.playerOverride, this.tasksOverride});

  final Player? playerOverride;
  final List<Task>? tasksOverride;

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  PlayerViewModel get _vm => context.read<PlayerViewModel>();

  Player _playerOf(BuildContext context) {
    if (widget.playerOverride != null) return widget.playerOverride!;
    return context.watch<PlayerViewModel>().player;
  }

  List<Task> _tasksOf(BuildContext context) {
    if (widget.tasksOverride != null) return widget.tasksOverride!;
    try {
      return context.watch<TaskViewModel>().tasks;
    } on ProviderNotFoundException {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        key: ProjectAppKeys.projectScreen,
        appBar: AppBar(title: const Text('計画の陣')),
        body: _buildBody(context),
        floatingActionButton: _playerOf(context).hasSkill(JobSkill.mysticProject)
            ? SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'project_create'),
                label: 'プロジェクトを作成',
                child: FloatingActionButton(
                  key: ProjectAppKeys.projectCreateFab,
                  onPressed: () => _showEditDialog(context, null),
                  child: const Icon(Icons.add),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final player = _playerOf(context);
    if (!player.hasSkill(JobSkill.mysticProject)) {
      return _LockedView();
    }
    final tasks = _tasksOf(context);
    final projects = ProjectService.listProjects(player);

    if (projects.isEmpty) {
      return Center(
        child: Column(
          key: ProjectAppKeys.projectEmptyState,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('プロジェクトがありません'),
            SizedBox(height: 8),
            Text('右下の ＋ から新しい計画を作ろう。'),
          ],
        ),
      );
    }

    final progresses = ProjectService.sortByProgress(
        projects.map((g) => ProjectService.progressFor(player, g, tasks)).toList());

    return ListView.builder(
          key: ProjectAppKeys.projectList,
          padding: const EdgeInsets.all(12),
          itemCount: progresses.length,
          itemBuilder: (context, index) => _ProjectRow(
              progress: progresses[index], index: index, tasks: tasks),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ProjectProgress? existing) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ProjectEditDialog(
        vm: _vm,
        existing: existing,
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text(
              '魔導師Lv10で解放',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '「計画の陣」スキルを習得すると、\nクエストを計画としてまとめられるようになります。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.progress,
    required this.index,
    required this.tasks,
  });

  final ProjectProgress progress;
  final int index;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ProjectAppKeys.projectRow(index),
      child: ListTile(
        title: Text(progress.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events,
                    size: 14, color: Colors.amber[400]),
                const SizedBox(width: 4),
                Text('ボーナス +${progress.bonusExp} EXP',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Text('クエスト ${progress.totalTasks}件',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress.ratio),
            const SizedBox(height: 4),
            Text(progress.progressLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress.isComplete)
              Icon(Icons.check_circle, color: Colors.green[400], size: 20),
            PopupMenuButton<String>(
              key: ProjectAppKeys.projectMenu(index),
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _edit(context);
                  case 'delete':
                    _delete(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('編集')),
                PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
            ),
          ],
        ),
        onTap: () => _showDetailSheet(context),
      ),
    );
  }

  void _edit(BuildContext context) {
    final vm = context.read<PlayerViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProjectEditDialog(vm: vm, existing: progress),
    );
  }

  void _delete(BuildContext context) {
    final vm = context.read<PlayerViewModel>();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        key: ProjectAppKeys.projectDeleteDialog,
        title: Text('「${progress.name}」を削除？'),
        content: const Text('プロジェクトと、所属クエストの割り当てが解除されます。\nクエストそのものは消えません。'),
        actions: [
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'project_delete_cancel'),
            label: '削除をやめる',
            child: TextButton(
              key: ProjectAppKeys.projectDeleteCancel,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('やめる'),
            ),
          ),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'project_delete_confirm'),
            label: '削除する',
            child: TextButton(
              key: ProjectAppKeys.projectDeleteConfirm,
              onPressed: () {
                vm.removeProject(progress.name);
                Navigator.of(context).pop();
              },
              child:
                  const Text('削除する', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    final vm = context.read<PlayerViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProjectDetailSheet(
        vm: vm,
        name: progress.name,
        tasks: tasks,
      ),
    );
  }
}

/// 共通の数値入力バリデーション（bonusExp）。
int? _parseBonus(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0;
  final v = int.tryParse(trimmed);
  if (v == null || v < 0) return null;
  return v;
}

/// 作成 / 編集ダイアログ。
class _ProjectEditDialog extends StatefulWidget {
  const _ProjectEditDialog({required this.vm, required this.existing});

  final PlayerViewModel vm;
  final ProjectProgress? existing;

  @override
  State<_ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<_ProjectEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bonusController;
  String? _nameError;
  String? _bonusError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _bonusController = TextEditingController(
        text: widget.existing == null ? '' : '${widget.existing!.bonusExp}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  void _submit() {
    final rawName = _nameController.text;
    final existingNames =
        ProjectService.listProjects(widget.vm.player).toList();
    if (_isEdit) {
      // 自分自身との重複は除外して検証
      existingNames.removeWhere((g) => g.name == widget.existing!.name);
    }
    final nameError = ProjectService.validateNew(existingNames, rawName);
    setState(() {
      _nameError = switch (nameError) {
        ProjectValidationError.empty => '名前を入力してください。',
        ProjectValidationError.tooLong =>
          '名前は${ProjectService.maxNameLength}文字以内にしてください。',
        ProjectValidationError.duplicate => '同じ名前の計画が既にあります。',
        null => null,
      };
      final bonus = _parseBonus(_bonusController.text);
      _bonusError =
          bonus == null ? '数値（0以上）を入力してください。' : null;

      if (_nameError != null || _bonusError != null) return;

      final name = ProjectService.normalize(rawName);
      if (_isEdit) {
        widget.vm.renameProject(widget.existing!.name, name,
            bonusExp: bonus);
      } else {
        widget.vm.addProject(name, bonus ?? 0);
      }
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: _isEdit
          ? ProjectAppKeys.projectEditDialog
          : ProjectAppKeys.projectCreateDialog,
      title: Text(_isEdit ? '計画を編集' : '新しい計画'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: ProjectAppKeys.projectNameField,
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '計画名',
                errorText: _nameError,
                counterText:
                    '${_nameController.text.length} / ${ProjectService.maxNameLength}',
              ),
              maxLength: ProjectService.maxNameLength + 10,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              key: ProjectAppKeys.projectBonusField,
              controller: _bonusController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '全達成ボーナス EXP',
                errorText: _bonusError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'project_cancel'),
          label: 'やめる',
          child: TextButton(
            key: ProjectAppKeys.projectCancel,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('やめる'),
          ),
        ),
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'project_submit'),
          label: _isEdit ? '計画を更新' : '計画を作成',
          child: ElevatedButton(
            key: _isEdit
                ? ProjectAppKeys.projectEditSubmit
                : ProjectAppKeys.projectSubmit,
            onPressed: _submit,
            child: Text(_isEdit ? '更新' : '作成'),
          ),
        ),
      ],
    );
  }
}

/// プロジェクト詳細ボトムシート — 所属クエストの解除と未割り当てクエストの割り当て。
class _ProjectDetailSheet extends StatelessWidget {
  const _ProjectDetailSheet({
    required this.vm,
    required this.name,
    required this.tasks,
  });

  final PlayerViewModel vm;
  final String name;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
    final player = vm.player;
    final assigned = ProjectService.tasksOf(player, name, tasks);
    final unassigned = ProjectService.unassignedTasks(player, tasks);

    return SafeArea(
      child: Container(
        key: ProjectAppKeys.projectDetailSheet,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('所属クエスト',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (assigned.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('所属クエストはありません。'),
              ),
            ...assigned.map((t) => ListTile(
                  dense: true,
                  leading: Icon(
                    t.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: t.isCompleted ? Colors.green : Colors.grey,
                  ),
                  title: Text(t.title),
                  trailing: SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'unassign_${t.id}'),
                    label: '${t.title}を計画から外す',
                    child: IconButton(
                      key: ProjectAppKeys.unassignButton(t.id),
                      icon: const Icon(Icons.link_off),
                      tooltip: '解除',
                      onPressed: () => vm.unassignTaskFromProject(t.id),
                    ),
                  ),
                )),
            const Divider(),
            const Text('未割り当てクエスト',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (unassigned.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('未割り当てのクエストはありません。'),
              ),
            ...unassigned.map((t) => ListTile(
                  dense: true,
                  title: Text(t.title),
                  trailing: SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'assign_${t.id}'),
                    label: '${t.title}を計画に追加',
                    child: IconButton(
                      key: ProjectAppKeys.assignButton(t.id),
                      icon: const Icon(Icons.add_link),
                      tooltip: '割り当て',
                      onPressed: () => vm.assignTaskToProject(t.id, name),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
    });
  }
}