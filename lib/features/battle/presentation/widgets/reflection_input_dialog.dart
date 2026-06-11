import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_badge_service.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

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
      widget.player!.recordReflection();
      final badgeMessages = <String>[];
      await ReflectionBadgeService.checkBadges(
        widget.player!,
        badgeMessages,
        repository: _repository,
        latestReflection: reflection,
      );
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
    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_reflection_input',
      child: Dialog(
        backgroundColor: const Color(0xFF1A2A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
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
                const Text(
                  '🌳 戦後の一息',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '「${widget.taskTitle}」の討伐、見事なり。',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'グリフォンの見立て: $_aiDifficultyLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8BC34A),
                  ),
                ),
                const SizedBox(height: 16),

                // Content input
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'このクエストで何を学んだ？',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '例: 小さく始める勇気が大事だと気づいた',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF4CAF50), width: 2),
                    ),
                    counterStyle: const TextStyle(color: Colors.white30),
                  ),
                ),
                const SizedBox(height: 20),

                // Self difficulty slider
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'このクエストの体感難易度は？',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('易', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _selfDifficulty.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: const Color(0xFF4CAF50),
                        inactiveColor: Colors.white12,
                        onChanged: (v) =>
                            setState(() => _selfDifficulty = v.round()),
                      ),
                    ),
                    const Text('難', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                Center(
                  child: Text(
                    _difficultyLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4CAF50),
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
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    'AI推定: $_aiDifficultyLabel  /  あなた: ${_selfDifficulty}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bonus notice
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '振り返りを記すと +${widget.inputBonusExp} EXP',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
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
                          foregroundColor: Colors.white38,
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
                                  color: Colors.white,
                                ),
                              )
                            : const Text('📝', style: TextStyle(fontSize: 18)),
                        label: const Text('記す'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
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
