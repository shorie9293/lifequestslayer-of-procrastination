import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';
import 'package:rpg_todo/features/shared/viewmodels/reduce_motion_view_model.dart';

/// 「動きを減らす」設定画面。
///
/// OS の視差効果設定に従うか、アプリ内で上書きするかを3択で選ぶ。
/// 試練用に [viewModel] / [repository] を任意注入できる：
/// [repository] が指定された場合は Provider（VM）無しでも動作する。
class ReduceMotionSettingsScreen extends StatefulWidget {
  const ReduceMotionSettingsScreen({super.key, this.viewModel, this.repository});

  /// 任意の ViewModel 注入（null なら `context.read<ReduceMotionViewModel>()`）。
  final ReduceMotionViewModel? viewModel;

  /// 任意の repository 注入。指定時は VM より優先し、VM 不要で動く。
  final ReduceMotionRepository? repository;

  @override
  State<ReduceMotionSettingsScreen> createState() =>
      _ReduceMotionSettingsScreenState();
}

class _ReduceMotionSettingsScreenState extends State<ReduceMotionSettingsScreen> {
  /// 注入 repository 使用時のローカル状態。
  ReduceMotionSetting _local = ReduceMotionSetting.system;

  @override
  void initState() {
    super.initState();
    _local = widget.viewModel?.setting ?? ReduceMotionSetting.system;
    final repo = widget.repository;
    if (repo != null) {
      // 保存済みの値を復元（VM 不在でも表示が正しくなるように）。
      repo.load().then((stored) {
        if (!mounted) return;
        final value = stored ?? ReduceMotionSetting.system;
        if (value == _local) return;
        setState(() => _local = value);
      }).catchError((Object e) {
        debugPrint('[ReduceMotion] 設定の復元に失敗: $e');
      });
    }
  }

  /// 選択肢ごとの説明文。
  static String _description(ReduceMotionSetting setting) {
    switch (setting) {
      case ReduceMotionSetting.system:
        return '端末の設定に従う';
      case ReduceMotionSetting.off:
        return 'アニメーションを通常どおり再生';
      case ReduceMotionSetting.on:
        return 'アニメーションを抑止して前庭障害に配慮';
    }
  }

  Future<void> _select(ReduceMotionSetting value) async {
    final repo = widget.repository;
    setState(() => _local = value);
    if (repo != null) {
      // 注入 repository を優先（VM 不要で永続化に到達する）
      await repo.save(value);
      return;
    }
    final vm = widget.viewModel ?? context.read<ReduceMotionViewModel>();
    await vm.setSetting(value);
  }

  @override
  Widget build(BuildContext context) {
    final hasInjectedRepo = widget.repository != null;
    ReduceMotionViewModel? vm;
    if (!hasInjectedRepo) {
      vm = widget.viewModel ?? context.watch<ReduceMotionViewModel>();
    }
    final current = hasInjectedRepo ? _local : (vm?.setting ?? _local);

    return Scaffold(
      appBar: AppBar(title: const Text('動きの設定')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.accessibility_new, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'アニメーションを減らすと、画面の動きによる不快感'
                        '（めまい・動揺病）を抑えられます。'
                        'WCAG 2.3.3（インタラクションによるアニメーション）に配慮した設定です。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          RadioGroup<ReduceMotionSetting>(
            groupValue: current,
            onChanged: (value) {
              if (value == null) return;
              _select(value);
            },
            child: Column(
              children: [
                for (final setting in ReduceMotionSetting.values)
                  RadioListTile<ReduceMotionSetting>(
                    key: ValueKey(
                        'reduce_motion_option_${setting.storageKey}'),
                    value: setting,
                    title: Text(setting.label),
                    subtitle: Text(_description(setting)),
                    secondary: Icon(setting.icon),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
