import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/domain/task_template.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';

/// 勤行の定型タスク（クイックテンプレート・改善提案 #73）の一覧画面。
///
/// - 定型の追加・編集・削除・検索
/// - ワンタップで寄合所へ起票（[onTaskCreated] に組立済み [Task] を渡す）
///
/// [repository] を注入できる（試練は InMemory、本番は getIt 経由で Hive 実装）。
class TaskTemplateScreen extends StatefulWidget {
  final TaskTemplateRepository? repository;
  final void Function(Task task)? onTaskCreated;

  const TaskTemplateScreen({super.key, this.repository, this.onTaskCreated});

  @override
  State<TaskTemplateScreen> createState() => _TaskTemplateScreenState();
}

class _TaskTemplateScreenState extends State<TaskTemplateScreen> {
  static const _service = TaskTemplateService();

  late final TaskTemplateRepository _repository =
      widget.repository ?? InMemoryTaskTemplateRepository();

  List<TaskTemplate> _templates = [];
  bool _loading = true;
  String _query = '';
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final templates = await _repository.load();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _persist(List<TaskTemplate> templates) async {
    setState(() => _templates = templates);
    await _repository.save(templates);
  }

  String _newId() =>
      'tmpl_${DateTime.now().microsecondsSinceEpoch}_${_templates.length}';

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openTemplateDialog({TaskTemplate? existing}) async {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    final result = await showDialog<_TemplateDialogResult>(
      context: context,
      builder: (_) => _TemplateEditDialog(
        existing: existing,
        existingNames: _templates
            .where((t) => t.id != existing?.id)
            .map((t) => t.name)
            .toList(),
      ),
    );
    _isDialogOpen = false;
    if (result == null) return;
    await handleDialogResult(
      name: result.name,
      title: result.title,
      rank: result.rank,
      repeatInterval: result.repeatInterval,
      repeatWeekdays: result.repeatWeekdays,
      subTaskTitles: result.subTaskTitles,
      targetTimeMinutes: result.targetTimeMinutes,
      existing: existing,
    );
  }

  /// ダイアログからの保存結果を受け取る（テスト容易性のため分離）。
  Future<void> handleDialogResult(
      {required String? name,
      required String title,
      required QuestRank rank,
      required RepeatInterval repeatInterval,
      required List<int> repeatWeekdays,
      required List<String> subTaskTitles,
      int? targetTimeMinutes,
      TaskTemplate? existing}) async {
    if (name == null) return; // キャンセル
    if (existing != null) {
      final updated = existing.copyWith(
        name: name,
        title: title,
        rank: rank,
        repeatInterval: repeatInterval,
        repeatWeekdays: repeatWeekdays,
        subTaskTitles: subTaskTitles,
        targetTimeMinutes: targetTimeMinutes,
        clearTargetTime: targetTimeMinutes == null,
      );
      await _persist([
        for (final t in _templates)
          if (t.id == existing.id) updated else t,
      ]);
      _showFeedback('定型を更新しました');
    } else {
      final template = TaskTemplate(
        id: _newId(),
        name: name,
        title: title,
        rank: rank,
        repeatInterval: repeatInterval,
        repeatWeekdays: repeatWeekdays,
        subTaskTitles: subTaskTitles,
        targetTimeMinutes: targetTimeMinutes,
      );
      await _persist([..._templates, template]);
      _showFeedback('定型を保存しました');
    }
    await _reload();
  }

  Future<void> _confirmDelete(TaskTemplate template) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: AppKeys.taskTemplateConfirmDelete,
        title: const Text('定型を削除'),
        content: Text('「${template.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: AppKeys.deleteButton,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _persist([
      for (final t in _templates)
        if (t.id != template.id) t,
    ]);
    _showFeedback('定型を削除しました');
  }

  void _createQuestFromTemplate(TaskTemplate template) {
    final task = _service.buildTask(template, id: _newId());
    widget.onTaskCreated?.call(task);
    _showFeedback('「${task.title}」を寄合所に起票しました');
  }

  @override
  Widget build(BuildContext context) {
    final visible = _service
        .searchByName(templates: _templates, query: _query)
        .toList();
    final sorted = _service.sortByName(visible);

    return Scaffold(
      key: AppKeys.taskTemplateScreen,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('勤行の定型'),
            const SizedBox(width: 8),
            Text('${sorted.length}件',
                key: AppKeys.taskTemplateCount,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: AppKeys.taskTemplateCreateButton,
        heroTag: 'taskTemplateCreate',
        tooltip: '定型を追加',
        child: const Icon(Icons.add),
        onPressed: () => _openTemplateDialog(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    key: AppKeys.taskTemplateSearchField,
                    decoration: InputDecoration(
                      hintText: '定型名・クエスト名で検索',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              key: AppKeys.taskTemplateSearchClear,
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _query = ''),
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: sorted.isEmpty
                      ? Center(
                          child: Column(
                            key: AppKeys.taskTemplateEmptyState,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark_border, size: 48),
                              const SizedBox(height: 8),
                              Text(_query.isEmpty
                                  ? '定型はまだありません\n右下の + で追加できます'
                                  : '一致する定型はありません'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          key: AppKeys.taskTemplateList,
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final t = sorted[index];
                            return _TemplateCard(
                              template: t,
                              onCreate: () => _createQuestFromTemplate(t),
                              onEdit: () => _openTemplateDialog(existing: t),
                              onDelete: () => _confirmDelete(t),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final TaskTemplate template;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  String get _subtitle {
    final parts = <String>['ランク${template.rank.name}'];
    switch (template.repeatInterval) {
      case RepeatInterval.daily:
        parts.add('毎日');
        break;
      case RepeatInterval.weekly:
        final days = template.repeatWeekdays.isEmpty
            ? null
            : (template.repeatWeekdays.toList()..sort())
                .map((d) => '月火水木金土日'[d - 1])
                .join('');
        if (days != null && days.isNotEmpty) parts.add('毎週($days)');
        break;
      case RepeatInterval.none:
        break;
    }
    if (template.subTaskTitles.isNotEmpty) {
      parts.add('サブタスク${template.subTaskTitles.length}');
    }
    if (template.targetTimeMinutes != null) {
      parts.add('${template.targetTimeMinutes}分');
    }
    return parts.join(' ・ ');
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = RankColors.forRank(template.rank);
    return Card(
      key: AppKeys.taskTemplateRow(template.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor.withValues(alpha: 0.2),
          child: Text(template.rank.name,
              style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
        ),
        title: Text(template.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.title),
            Text(_subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        isThreeLine: true,
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: AppKeys.taskTemplateCreateQuestButton,
              icon: const Icon(Icons.playlist_add_check),
              tooltip: 'この定型でクエストを起票',
              onPressed: onCreate,
            ),
            IconButton(
              key: AppKeys.taskTemplateDeleteButton,
              icon: const Icon(Icons.delete_outline),
              tooltip: '定型を削除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// 定型の追加・編集ダイアログ。pop 時に引数で結果を返す:
/// - 保存成功: name（null 以外）
/// - キャンセル: null
class _TemplateEditDialog extends StatefulWidget {
  final TaskTemplate? existing;
  final List<String> existingNames;

  const _TemplateEditDialog({this.existing, required this.existingNames});

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  static const _service = TaskTemplateService();

  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _subTaskController;
  late final TextEditingController _targetTimeController;
  late QuestRank _rank;
  late RepeatInterval _repeat;
  late List<int> _weekdays;
  late List<String> _subTasks;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _titleController = TextEditingController(text: e?.title ?? '');
    _subTaskController = TextEditingController();
    _targetTimeController =
        TextEditingController(text: e?.targetTimeMinutes?.toString() ?? '');
    _rank = e?.rank ?? QuestRank.B;
    _repeat = e?.repeatInterval ?? RepeatInterval.none;
    _weekdays = e != null ? List<int>.from(e.repeatWeekdays) : [];
    _subTasks = e != null ? List<String>.from(e.subTaskTitles) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _subTaskController.dispose();
    _targetTimeController.dispose();
    super.dispose();
  }

  void _addSubTask() {
    final v = _subTaskController.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _subTasks.add(v);
      _subTaskController.clear();
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final title = _titleController.text.trim();
    final problems = <String>[
      ..._service.validateNew(name: name, existing: const []),
      if (title.isEmpty) 'クエスト名が空です',
    ];
    // 名前衝突（自分以外）を検査するため existingNames を別途確認
    if (widget.existingNames
        .any((n) => _service.comparisonKey(n) == _service.comparisonKey(name))) {
      problems.add('同名の定型が既に存在します');
    }
    if (problems.isNotEmpty) {
      setState(() => _errorText = problems.first);
      return;
    }
    int? targetTime = int.tryParse(_targetTimeController.text);
    if (targetTime != null && targetTime < 0) targetTime = null;
    if (_repeat == RepeatInterval.weekly && _weekdays.isEmpty) {
      _weekdays = [DateTime.now().weekday];
    }
    Navigator.pop(context, _TemplateDialogResult(
      name: name,
      title: title,
      rank: _rank,
      repeatInterval: _repeat,
      repeatWeekdays: List<int>.from(_weekdays),
      subTaskTitles: List<String>.from(_subTasks),
      targetTimeMinutes: targetTime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '定型を追加' : '定型を編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              key: AppKeys.taskTemplateNameField,
              decoration: const InputDecoration(labelText: '定型名'),
            ),
            TextField(
              controller: _titleController,
              key: AppKeys.taskTemplateTitleField,
              decoration: const InputDecoration(labelText: 'クエスト名'),
            ),
            DropdownButtonFormField<QuestRank>(
              initialValue: _rank,
              decoration: const InputDecoration(labelText: 'ランク'),
              items: [
                for (final r in QuestRank.values)
                  DropdownMenuItem(value: r, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _rank = v ?? _rank),
            ),
            DropdownButtonFormField<RepeatInterval>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: '繰り返し'),
              items: const [
                DropdownMenuItem(
                    value: RepeatInterval.none, child: Text('繰り返しなし')),
                DropdownMenuItem(
                    value: RepeatInterval.daily, child: Text('毎日')),
                DropdownMenuItem(
                    value: RepeatInterval.weekly, child: Text('毎週')),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? _repeat),
            ),
            if (_repeat == RepeatInterval.weekly)
              Wrap(
                spacing: 4,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text('月火水木金土日'[d - 1]),
                      selected: _weekdays.contains(d),
                      onSelected: (sel) => setState(() {
                        sel ? _weekdays.add(d) : _weekdays.remove(d);
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            const Text('サブタスク', style: TextStyle(fontSize: 12)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskController,
                    key: AppKeys.taskTemplateSubTaskField,
                    decoration: const InputDecoration(hintText: 'サブタスク名'),
                    onSubmitted: (_) => _addSubTask(),
                  ),
                ),
                IconButton(
                  key: AppKeys.taskTemplateSubTaskAdd,
                  icon: const Icon(Icons.add),
                  tooltip: 'サブタスクを追加',
                  onPressed: _addSubTask,
                ),
              ],
            ),
            for (var i = 0; i < _subTasks.length; i++)
              Row(
                children: [
                  Expanded(child: Text(_subTasks[i])),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _subTasks.removeAt(i)),
                  ),
                ],
              ),
            TextField(
              controller: _targetTimeController,
              decoration:
                  const InputDecoration(labelText: '見積もり時間（分・任意）'),
              keyboardType: TextInputType.number,
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          key: AppKeys.taskTemplateSaveButton,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _TemplateDialogResult {
  final String name;
  final String title;
  final QuestRank rank;
  final RepeatInterval repeatInterval;
  final List<int> repeatWeekdays;
  final List<String> subTaskTitles;
  final int? targetTimeMinutes;

  const _TemplateDialogResult({
    required this.name,
    required this.title,
    required this.rank,
    required this.repeatInterval,
    required this.repeatWeekdays,
    required this.subTaskTitles,
    required this.targetTimeMinutes,
  });
}
