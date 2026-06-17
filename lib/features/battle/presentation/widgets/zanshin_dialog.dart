import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 残心【初段】— 侍系プレイヤーの戦後ダイアログ。
///
/// 討伐完了後、戦果報告書の次に表示される。
/// 【⚔️ 会心】か【💧 戒め】の2択で振り返りを行い、
/// それぞれ異なる形で討伐の余韻を味わう。
class ZanshinDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final QuestRank aiDifficulty;
  final int inputBonusExp;
  final VoidCallback onKaishin;
  final VoidCallback onImashime;
  final Player? player;

  const ZanshinDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.aiDifficulty,
    this.inputBonusExp = 50,
    required this.onKaishin,
    required this.onImashime,
    this.player,
  });

  /// ダイアログを表示する。
  static Future<void> show(
    BuildContext context, {
    required String taskId,
    required String taskTitle,
    required QuestRank aiDifficulty,
    int inputBonusExp = 50,
    required VoidCallback onKaishin,
    required VoidCallback onImashime,
    Player? player,
  }) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ZanshinDialog(
          taskId: taskId,
          taskTitle: taskTitle,
          aiDifficulty: aiDifficulty,
          inputBonusExp: inputBonusExp,
          onKaishin: onKaishin,
          onImashime: onImashime,
          player: player,
        ),
      );

  @override
  State<ZanshinDialog> createState() => _ZanshinDialogState();
}

class _ZanshinDialogState extends State<ZanshinDialog> {
  bool _imashimeMode = false;
  final _contentController = TextEditingController();
  bool _isSaving = false;

  final _repository = ReflectionRepository();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _onKaishin() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final reflection = Reflection(
      id: const Uuid().v4(),
      taskId: widget.taskId,
      date: DateTime.now(),
      content: '会心の一撃',
      selfDifficulty: 3,
      aiDifficulty: widget.aiDifficulty,
      sentiment: 'kaishin',
    );

    await _repository.save(reflection);

    widget.onKaishin();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openImashimeInput() {
    setState(() => _imashimeMode = true);
  }

  Future<void> _submitImashime() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final content = _contentController.text.trim();

    final reflection = Reflection(
      id: const Uuid().v4(),
      taskId: widget.taskId,
      date: DateTime.now(),
      content: content,
      selfDifficulty: 3,
      aiDifficulty: widget.aiDifficulty,
      sentiment: 'imashime',
    );

    await _repository.save(reflection);

    // 知恵ポイント蓄積
    widget.player?.wisdomPoints = (widget.player?.wisdomPoints ?? 0) + 1;

    widget.onImashime();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_zanshin',
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFC62828), width: 1.5),
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
                  '⚔️ 残心の刻',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC62828),
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
                const Text(
                  '太刀を収める前に、己が心を省みよ。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFEF9A9A),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                if (!_imashimeMode) ...[
                  // ━━━ 2択ボタン ━━━
                  // 【⚔️ 会心】
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'zanshin_kaishin'),
                    label: '会心の一撃',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _onKaishin,
                        icon: const Text('⚔️', style: TextStyle(fontSize: 20)),
                        label: const Text('会心 — 見事な太刀筋',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bonus XP notice
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '+${widget.inputBonusExp} EXP ボーナス',
                          style: const TextStyle(
                            color: Color(0xFFEF9A9A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 【💧 戒め】
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'zanshin_imashime'),
                    label: '戒めを刻む',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _openImashimeInput,
                        icon: const Text('💧', style: TextStyle(fontSize: 20)),
                        label: const Text('戒め — 次に活かす',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF37474F),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // ━━━ 戒め入力フォーム ━━━
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '💧 戒めを刻む',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF90A4AE),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '次に活かすために、心に留めておくことを記せ。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _contentController,
                    maxLines: 3,
                    maxLength: 100,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '例: 準備を怠らぬこと',
                      hintStyle:
                          const TextStyle(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFF90A4AE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF90A4AE), width: 2),
                      ),
                      counterStyle: const TextStyle(color: Colors.white30),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 知恵ポイントの案内
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧠', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        const Text(
                          '戒めを刻むと 知恵ポイント +1',
                          style: TextStyle(
                            color: Color(0xFF90A4AE),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 送信ボタン
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'zanshin_submit_imashime'),
                    label: '戒めを刻む',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitImashime,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('💧',
                                style: TextStyle(fontSize: 18)),
                        label: const Text('戒めを刻む'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF37474F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
