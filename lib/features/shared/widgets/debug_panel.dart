import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/domain/backup_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// デバッグパネル — ModalBottomSheetで値を自由操作
///
/// コイン/Gemの直接設定、EXP追加、クエスト一括完了、テストクエスト追加が可能。
/// SettingsViewModel.isDebugMode == true の時のみ表示される。
class DebugPanel extends StatefulWidget {
  final SettingsViewModel settingsVM;

  const DebugPanel({super.key, required this.settingsVM});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late final TextEditingController _coinCtrl;
  late final TextEditingController _gemCtrl;

  @override
  void initState() {
    super.initState();
    final p = context.read<PlayerViewModel>().player;
    _coinCtrl = TextEditingController(text: p.coins.toString());
    _gemCtrl = TextEditingController(text: p.gems.toString());
  }

  @override
  void dispose() {
    _coinCtrl.dispose();
    _gemCtrl.dispose();
    super.dispose();
  }

  void _setCoins() {
    final v = int.tryParse(_coinCtrl.text);
    if (v != null) {
      context.read<PlayerViewModel>().debugSetCoins(v);
      _coinCtrl.text = context.read<PlayerViewModel>().player.coins.toString();
    }
  }

  void _setGems() {
    final v = int.tryParse(_gemCtrl.text);
    if (v != null) {
      context.read<PlayerViewModel>().debugSetGems(v);
      _gemCtrl.text = context.read<PlayerViewModel>().player.gems.toString();
    }
  }

  void _addExp(int amount) {
    context.read<PlayerViewModel>().addExp(amount);
    setState(() {}); // レベル表示更新のため
  }

  void _completeAll() {
    context.read<TaskViewModel>().debugCompleteAllActive();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全アクティブクエストを完了しました'), duration: Duration(seconds: 1)),
    );
  }

  void _addTestTasks() {
    context.read<TaskViewModel>().debugAddTestTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('テスト用クエストを3件追加しました'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerViewModel>().player;
    final lvl = p.level;
    final exp = p.currentExp;
    final nextExp = _expForLevel(lvl + 1);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Row(
              children: [
                const Icon(Icons.construction, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text('デバッグパネル', style: theme.textTheme.titleMedium?.copyWith(color: Colors.amber)),
                const Spacer(),
                Text('Lv.$lvl  EXP:$exp/$nextExp', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),

            // コイン設定
            _sectionLabel('💰 コイン'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _coinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'コイン 現在: ${p.coins}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(SemanticTypes.button, 'debug_set_coins'),
                  child: ElevatedButton(onPressed: _setCoins, child: const Text('設定')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gem設定
            _sectionLabel('💎 Gem'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gemCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: '現在: ${p.gems}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(SemanticTypes.button, 'debug_set_gems'),
                  child: ElevatedButton(onPressed: _setGems, child: const Text('設定')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // EXP追加
            _sectionLabel('⚔️ EXP追加'),
            const SizedBox(height: 8),
            Row(
              children: [
                _expButton(100),
                const SizedBox(width: 8),
                _expButton(500),
                const SizedBox(width: 8),
                _expButton(1000),
              ],
            ),
            const SizedBox(height: 16),

            // クエスト操作
            _sectionLabel('📋 クエスト操作'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(SemanticTypes.button, 'debug_complete_all'),
                    child: OutlinedButton.icon(
                      onPressed: _completeAll,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('全クエスト完了'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(SemanticTypes.button, 'debug_add_test_tasks'),
                    child: OutlinedButton.icon(
                      onPressed: _addTestTasks,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('テストクエスト追加'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // フォントサイズ調整
            _sectionLabel('🔤 フォントサイズ'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('小', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: widget.settingsVM.fontSizeScale,
                    min: 0.6,
                    max: 1.4,
                    divisions: 16,
                    label: '${(widget.settingsVM.fontSizeScale * 100).round()}%',
                    onChanged: (v) => widget.settingsVM.setFontSizeScale(v),
                  ),
                ),
                const Text('大', style: TextStyle(fontSize: 18)),
              ],
            ),
            Center(
              child: Text(
                '現在: ${(widget.settingsVM.fontSizeScale * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // バックアップ（道標§五#17: データエクスポート＆バックアップ可視化）
            _sectionLabel('💾 バックアップ'),
            const SizedBox(height: 8),
            _buildBackupSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection(ThemeData theme) {
    final lastBackup = widget.settingsVM.lastBackupTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lastBackup == null
              ? '最終バックアップ: 未実行'
              : '最終バックアップ: ${lastBackup.toLocal()}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'backup_export'),
                child: OutlinedButton.icon(
                  onPressed: _exportBackup,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('エクスポート'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'backup_restore'),
                child: OutlinedButton.icon(
                  onPressed: _restoreBackup,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('復元'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Player + タスクを JSON に直列化しクリップボードへコピー、日時を記録。
  Future<void> _exportBackup() async {
    final player = context.read<PlayerViewModel>().player;
    final tasks = context.read<TaskViewModel>().tasks;
    final json = BackupService.buildBackupJson(
      player: player,
      tasks: tasks,
      exportedAt: DateTime.now(),
    );
    await Clipboard.setData(ClipboardData(text: json));
    await widget.settingsVM.recordBackupNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('バックアップをコピーしました（${tasks.length}件のクエスト）'),
          duration: const Duration(seconds: 2)),
    );
  }

  /// クリップボードの JSON から復元可能か検証し、結果を通知する。
  Future<void> _restoreBackup() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) {
      _showBackupMessage('クリップボードにバックアップデータがありません');
      return;
    }
    try {
      final snapshot = BackupService.parseBackupJson(data.text!);
      _showBackupMessage(
          '復元可能です（Player ${snapshot.player?.coins ?? '-'}コイン, クエスト${snapshot.tasks.length}件）。'
          '実際の反映はデータ復元画面から行ってください。');
    } on FormatException catch (e) {
      _showBackupMessage('復元できません: ${e.message}');
    }
  }

  void _showBackupMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }

  Widget _expButton(int amount) {
    return Expanded(
      child: SemanticHelper.interactive(
        testId: SemanticHelper.createTestId(SemanticTypes.button, 'debug_add_exp_$amount'),
        child: ElevatedButton(
          onPressed: () => _addExp(amount),
          child: Text('+$amount'),
        ),
      ),
    );
  }

  /// 簡易レベルテーブル（rpg-taskの実際の計算と揃える）
  static int _expForLevel(int level) {
    // Player.addExpの計算式: required = (level * (level + 1)) * 5
    return (level * (level + 1)) * 5;
  }
}
