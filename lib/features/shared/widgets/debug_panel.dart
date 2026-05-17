import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../viewmodels/game_view_model.dart';

/// デバッグパネル — ModalBottomSheetで値を自由操作
///
/// コイン/Gemの直接設定、EXP追加、タスク一括完了、テストタスク追加が可能。
/// GameViewModel.isDebugMode == true の時のみ表示される。
class DebugPanel extends StatefulWidget {
  final GameViewModel vm;

  const DebugPanel({super.key, required this.vm});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late final TextEditingController _coinCtrl;
  late final TextEditingController _gemCtrl;

  @override
  void initState() {
    super.initState();
    _coinCtrl = TextEditingController(text: widget.vm.player.coins.toString());
    _gemCtrl = TextEditingController(text: widget.vm.player.gems.toString());
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
      widget.vm.debugSetCoins(v);
      _coinCtrl.text = widget.vm.player.coins.toString();
    }
  }

  void _setGems() {
    final v = int.tryParse(_gemCtrl.text);
    if (v != null) {
      widget.vm.debugSetGems(v);
      _gemCtrl.text = widget.vm.player.gems.toString();
    }
  }

  void _addExp(int amount) {
    widget.vm.debugAddExp(amount);
    setState(() {}); // レベル表示更新のため
  }

  void _completeAll() {
    widget.vm.debugCompleteAllActive();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全アクティブタスクを完了しました'), duration: Duration(seconds: 1)),
    );
  }

  void _addTestTasks() {
    widget.vm.debugAddTestTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('テスト用タスクを3件追加しました'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.vm.player;
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
                ElevatedButton(onPressed: _setCoins, child: const Text('設定')),
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
                ElevatedButton(onPressed: _setGems, child: const Text('設定')),
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

            // タスク操作
            _sectionLabel('📋 タスク操作'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _completeAll,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('全タスク完了'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addTestTasks,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('テストタスク追加'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }

  Widget _expButton(int amount) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _addExp(amount),
        child: Text('+$amount'),
      ),
    );
  }

  /// 簡易レベルテーブル（rpg-taskの実際の計算と揃える）
  static int _expForLevel(int level) {
    // Player.addExpの計算式: required = (level * (level + 1)) * 5
    return (level * (level + 1)) * 5;
  }
}
