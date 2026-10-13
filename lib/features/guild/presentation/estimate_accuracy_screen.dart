import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_time_record_repository.dart';
import 'package:rpg_todo/features/guild/domain/estimate_accuracy.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';

import 'estimate_accuracy_keys.dart';

/// 見積もり精度レポート画面（改善提案 #131）。
///
/// タスクごとの「見積もり vs 実績」記録を一覧し、的中率・平均誤差を
/// [EstimateAccuracyService] で集計して表示する。
///
/// [recordsOverride]・[tasksOverride]・[repository] を注入でき、
/// 実 Hive に依存せず試練可能。未注入時の既定リポジトリは
/// getIt 登録済みの [TaskTimeRecordRepository]、無ければ
/// [InMemoryTaskTimeRecordRepository]（UI試練環境の安全側）。
class EstimateAccuracyScreen extends StatefulWidget {
  const EstimateAccuracyScreen({
    super.key,
    this.recordsOverride,
    this.tasksOverride,
    this.repository,
  });

  /// 表示する記録（試練用に注入できる）。指定時はリポジトリから読まない。
  final List<TaskTimeRecord>? recordsOverride;

  /// 記録ダイアログで選べるクエスト（試練用に注入できる）。
  /// 未指定時は [GameViewModel].tasks を使う。
  final List<Task>? tasksOverride;

  /// 永続化リポジトリ（試練用に注入できる）。
  final TaskTimeRecordRepository? repository;

  @override
  State<EstimateAccuracyScreen> createState() => _EstimateAccuracyScreenState();
}

class _EstimateAccuracyScreenState extends State<EstimateAccuracyScreen> {
  List<TaskTimeRecord> _loaded = const [];
  TaskTimeRecordRepository? _fallbackRepository;
  bool _loading = true;

  /// widget 由来の値は getter で参照する（State 再利用に耐える）。
  List<TaskTimeRecord> get _records => widget.recordsOverride ?? _loaded;

  TaskTimeRecordRepository get _repository {
    final injected = widget.repository;
    if (injected != null) return injected;
    return _fallbackRepository ??= _resolveRepository();
  }

  static TaskTimeRecordRepository _resolveRepository() {
    if (getIt.isRegistered<TaskTimeRecordRepository>()) {
      return getIt<TaskTimeRecordRepository>();
    }
    // UI試練環境など getIt 未登録の安全側。実 Hive は開かない。
    return InMemoryTaskTimeRecordRepository();
  }

  @override
  void initState() {
    super.initState();
    if (widget.recordsOverride != null) {
      _loading = false;
    } else {
      _reload();
    }
  }

  /// 必ずリポジトリから再読込して一覧に反映する。
  Future<void> _reload() async {
    try {
      final records = await _repository.loadAll();
      if (!mounted) return;
      setState(() {
        _loaded = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openAddDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RecordDialog(
        tasks: widget.tasksOverride ?? context.read<GameViewModel>().tasks,
        repository: _repository,
      ),
    );
    await _reload();
  }

  Future<void> _deleteRecord(TaskTimeRecord record) async {
    await _repository.delete(record.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final records = EstimateAccuracyService.sortByRecordedAtDesc(_records);
    final stats = EstimateAccuracyService.buildStats(_records);

    return Scaffold(
      key: EstimateAccuracyKeys.screen,
      appBar: AppBar(
        title: const Text('見積もり精度レポート'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(stats),
                const Divider(height: 1),
                Expanded(
                  child: records.isEmpty
                      ? _buildEmptyState()
                      : _buildRecordList(records),
                ),
              ],
            ),
      floatingActionButton: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(
            SemanticTypes.button, 'estimate_accuracy_add'),
        label: '実績を記録',
        child: FloatingActionButton.extended(
          key: EstimateAccuracyKeys.addButton,
          onPressed: _openAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('実績を記録'),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(EstimateAccuracyStats stats) {
    return Card(
      key: EstimateAccuracyKeys.summaryCard,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              EstimateAccuracyService.summaryLabel(stats),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('🎯 的中率',
                    key: EstimateAccuracyKeys.summaryOnTargetRate,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(stats.onTargetRateLabel,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                Text('📊 平均誤差',
                    key: EstimateAccuracyKeys.summaryAverageError,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(stats.averageErrorRateLabel,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(stats.averageTimeLabel, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: EstimateAccuracyKeys.emptyState,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🧭', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('まだ記録がありません。'),
          SizedBox(height: 8),
          Text('「実績を記録」から見積もりと実績を残そう。'),
        ],
      ),
    );
  }

  Widget _buildRecordList(List<TaskTimeRecord> records) {
    return ListView.builder(
      key: EstimateAccuracyKeys.list,
      itemCount: records.length,
      itemBuilder: (context, index) => _buildRecordRow(records[index]),
    );
  }

  Widget _buildRecordRow(TaskTimeRecord record) {
    final level = EstimateAccuracyService.levelOf(record);
    final errorPct =
        (EstimateAccuracyService.errorRateOf(record) * 100).round();
    final errorLabel =
        errorPct == 0 ? '±0%' : errorPct > 0 ? '+$errorPct%' : '$errorPct%';
    final d = record.recordedAt;
    final dateLabel =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return ListTile(
      key: EstimateAccuracyKeys.recordRow(record.id),
      title: Text(
        record.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('見積 ${record.estimatedMinutes}分 / 実績 ${record.actualMinutes}分',
              style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              Text('${level.emoji} ${level.label}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Text('誤差 $errorLabel', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Text(dateLabel, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
      trailing: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(
            SemanticTypes.button, 'estimate_accuracy_delete_${record.id}'),
        label: '記録を削除',
        child: IconButton(
          key: EstimateAccuracyKeys.deleteButton(record.id),
          icon: const Icon(Icons.delete_outline),
          tooltip: '記録を削除',
          onPressed: () => _deleteRecord(record),
        ),
      ),
    );
  }
}

/// 「実績を記録」ダイアログ。
class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.tasks, required this.repository});

  final List<Task> tasks;
  final TaskTimeRecordRepository repository;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  Task? _selectedTask;
  final TextEditingController _estimatedController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _estimatedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  void _selectTask(Task? task) {
    setState(() {
      _selectedTask = task;
      _error = null;
      final estimate = task?.targetTimeMinutes;
      if (estimate != null) {
        _estimatedController.text = '$estimate';
      }
    });
  }

  Future<void> _save() async {
    if (widget.tasks.isEmpty) {
      setState(() => _error = '記録できるクエストがありません');
      return;
    }
    final task = _selectedTask;
    if (task == null) {
      setState(() => _error = 'クエストを選択してください');
      return;
    }
    final estimated = int.tryParse(_estimatedController.text.trim());
    final actual = int.tryParse(_actualController.text.trim());
    if (estimated == null || estimated <= 0 || actual == null || actual <= 0) {
      setState(() => _error = '見積もり・実績は1以上の整数で入力してください');
      return;
    }
    // まずリポジトリに保存し、その後に画面側で再読込させる。
    await widget.repository.save(TaskTimeRecord(
      taskId: task.id,
      title: task.title,
      estimatedMinutes: estimated,
      actualMinutes: actual,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasTasks = widget.tasks.isNotEmpty;
    return AlertDialog(
      key: EstimateAccuracyKeys.dialog,
      title: const Text('実績を記録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasTasks) ...[
              const Text('記録できるクエストがありません。'),
              const SizedBox(height: 8),
            ] else
              DropdownButtonFormField<Task>(
                key: EstimateAccuracyKeys.taskField,
                initialValue: _selectedTask,
                decoration: const InputDecoration(labelText: 'クエスト'),
                items: [
                  for (final task in widget.tasks)
                    DropdownMenuItem<Task>(
                      value: task,
                      child: Text(
                        '${task.title}（見積 ${task.targetTimeMinutes ?? 0}分）',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _selectTask,
              ),
            TextField(
              key: EstimateAccuracyKeys.estimatedField,
              controller: _estimatedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '見積もり（分）'),
            ),
            TextField(
              key: EstimateAccuracyKeys.actualField,
              controller: _actualController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '実績（分）'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: EstimateAccuracyKeys.cancelButton,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: EstimateAccuracyKeys.saveButton,
          onPressed: hasTasks ? _save : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
