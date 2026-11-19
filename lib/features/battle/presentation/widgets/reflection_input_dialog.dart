import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 緑の塗りボタン（背景 #4CAF50 / ライトは #1B5E20）の上の前景。
const Color _onFilledButton = Color(0xFFFFFFFF);

/// 討伐後の一息——振り返り入力ダイアログ。
///
/// 戦果報告書の後に表示し、任意で「何を学んだか」の短文と
/// 自己評価難易度（1-5）を入力できる。
/// 入力に応じてボーナスXPが付与される。
///
/// [player] が指定された場合、保存時に内省バッジのチェックが行われる。
class ReflectionInputDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final QuestRank aiDifficulty;
  final int inputBonusExp;
  final VoidCallback onSaved;
  final VoidCallback onSkipped;
  final Player? player;

  const ReflectionInputDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.aiDifficulty,
    required this.inputBonusExp,
    required this.onSaved,
    required this.onSkipped,
    this.player,
  });

  /// ダイアログを表示する。
  /// 戻り値は true=入力あり, false=スキップ, null=ダイアログが閉じられた
  static Future<bool?> show(
    BuildContext context, {
    required String taskId,
    required String taskTitle,
    required QuestRank aiDifficulty,
    int inputBonusExp = 50,
    required VoidCallback onSaved,
    Player? player,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ReflectionInputDialog(
        taskId: taskId,
        taskTitle: taskTitle,
        aiDifficulty: aiDifficulty,
        inputBonusExp: inputBonusExp,
        onSaved: onSaved,
        onSkipped: () {},
        player: player,
      ),
    );
  }

  @override
  State<ReflectionInputDialog> createState() => _ReflectionInputDialogState();
}

class _ReflectionInputDialogState extends State<ReflectionInputDialog> {
  final _contentController = TextEditingController();
  int _selfDifficulty = 3;
  bool _isSaving = false;

  final _repository = ReflectionRepository();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final reflection = Reflection(
      id: const Uuid().v4(),
      taskId: widget.taskId,
      date: DateTime.now(),
      content: _contentController.text.trim(),
      selfDifficulty: _selfDifficulty,
      aiDifficulty: widget.aiDifficulty,
    );

    await _repository.save(reflection);

    // プレイヤーが指定されていれば内省バッジをチェック
    if (widget.player != null) {
      final badgeMessages = <String>[];
      // PlayerViewModel 委譲（イミュータブル化第二十二段）。
      // recordReflection 純粋化＋checkBadges copyWith化は VM が担う。
      try {
        await context.read<PlayerViewModel>().checkReflectionBadges(
          repository: _repository,
          latestReflection: reflection,
          bonusMessages: badgeMessages,
        );
      } catch (_) {
        // Provider ツリー外（防御: 本番では常にProvider配下で表示される）
      }
      // バッジ獲得メッセージがあれば onSaved の前に SnackBar で通知
      if (badgeMessages.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(badgeMessages.join('\n')),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    }

    widget.onSaved();

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _skip() {
    widget.onSkipped();
    Navigator.of(context).pop(false);
  }

  String get _difficultyLabel {
    switch (_selfDifficulty) {
      case 1:
        return '🌟 朝飯前';
      case 2:
        return '🍃 やや易し';
      case 3:
        return '⚖️ ほどほど';
      case 4:
        return '🔥 手強し';
      case 5:
        return '💀 至難の業';
      default:
        return '⚖️ ほどほど';
    }
  }

  String get _aiDifficultyLabel {
    switch (widget.aiDifficulty) {
      case QuestRank.S:
        return 'Sランク';
      case QuestRank.A:
        return 'Aランク';
      case QuestRank.B:
        return 'Bランク';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_reflection_input',
      child: Dialog(
        // ダークは従来の暗幕色のまま、ライトはテーマ既定の明るい面へ。
        backgroundColor: palette.isLight ? null : const Color(0xFF1A2A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.success, width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Text(
                  '🌳 戦後の一息',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: palette.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '「${widget.taskTitle}」の討伐、見事なり。',
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.onSurfaceMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'グリフォンの見立て: $_aiDifficultyLabel',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.readable(const Color(0xFF8BC34A)),
                  ),
                ),
                const SizedBox(height: 16),

                // Content input
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'このクエストで何を学んだ？',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  maxLines: 3,
                  maxLength: 200,
                  style: TextStyle(color: palette.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '例: 小さく始める勇気が大事だと気づいた',
                    hintStyle: TextStyle(
                        color: palette.onSurfaceFaintest, fontSize: 13),
                    filled: true,
                    fillColor: palette.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.success),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: palette.success, width: 2),
                    ),
                    counterStyle:
                        TextStyle(color: palette.onSurfaceFaintest),
                  ),
                ),
                const SizedBox(height: 20),

                // Self difficulty slider
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'このクエストの体感難易度は？',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('易',
                        style: TextStyle(
                            color: palette.onSurfaceFaint, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _selfDifficulty.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: palette.success,
                        inactiveColor: palette.border,
                        onChanged: (v) =>
                            setState(() => _selfDifficulty = v.round()),
                      ),
                    ),
                    Text('難',
                        style: TextStyle(
                            color: palette.onSurfaceFaint, fontSize: 12)),
                  ],
                ),
                Center(
                  child: Text(
                    _difficultyLabel,
                    style: TextStyle(
                      fontSize: 16,
                      color: palette.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Comparison hint
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'AI推定: $_aiDifficultyLabel  /  あなた: $_selfDifficulty',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.onSurfaceFaint,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bonus notice
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '振り返りを記すと +${widget.inputBonusExp} EXP',
                        style: TextStyle(
                          color: palette.success,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SemanticHelper.interactive(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.button, 'skip_reflection'),
                      label: '振り返りをスキップ',
                      child: TextButton(
                        onPressed: _isSaving ? null : _skip,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.onSurfaceFaint,
                        ),
                        child: const Text('スキップ'),
                      ),
                    ),
                    SemanticHelper.interactive(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.button, 'save_reflection'),
                      label: '振り返りを記す',
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _onFilledButton,
                                ),
                              )
                            : const Text('📝', style: TextStyle(fontSize: 18)),
                        label: const Text('記す'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.success,
                          foregroundColor: _onFilledButton,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
