import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 塗りボタン（#C62828 / #37474F）の上の前景。暗色の塗りなので明度テーマに
/// 依らず白系が正しい（実測 7:1 以上）。
const Color _onFilledButton = Color(0xFFFFFFFF);
const Color _onFilledButtonMuted = Color(0xB3FFFFFF); // 旧 white70

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

  /// 振り返り保存先リポジトリ（テスト注入用）。null なら実 Hive を使用。
  final ReflectionRepository? repository;

  const ZanshinDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.aiDifficulty,
    this.inputBonusExp = 50,
    required this.onKaishin,
    required this.onImashime,
    this.repository,
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
    ReflectionRepository? repository,
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
          repository: repository,
        ),
      );

  @override
  State<ZanshinDialog> createState() => _ZanshinDialogState();
}

class _ZanshinDialogState extends State<ZanshinDialog> {
  bool _imashimeMode = false;
  final _contentController = TextEditingController();
  bool _isSaving = false;

  late final ReflectionRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReflectionRepository();
  }

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

    // 知恵ポイント蓄積（PlayerViewModel 委譲・v2.5.81イミュータブル化第十九段）
    try {
      context.read<PlayerViewModel>().addWisdomPoint();
    } catch (_) {
      // Provider ツリー外（防御: 本番では常にProvider配下で表示される）
    }

    widget.onImashime();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_zanshin',
      child: Dialog(
        // ダークは従来の暗幕色のまま、ライトはテーマ既定の明るい面へ。
        backgroundColor: palette.isLight ? null : const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: palette.readable(const Color(0xFFC62828)), width: 1.5),
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
                  '⚔️ 残心の刻',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: palette.readable(const Color(0xFFC62828)),
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
                  '太刀を収める前に、己が心を省みよ。',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.readable(const Color(0xFFEF9A9A)),
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
                          foregroundColor: _onFilledButton,
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
                          style: TextStyle(
                            color: palette.readable(const Color(0xFFEF9A9A)),
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
                          foregroundColor: _onFilledButtonMuted,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '💧 戒めを刻む',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: palette.readable(const Color(0xFF90A4AE)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '次に活かすために、心に留めておくことを記せ。',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.onSurfaceFaint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _contentController,
                    maxLines: 3,
                    maxLength: 100,
                    autofocus: true,
                    style: TextStyle(color: palette.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '例: 準備を怠らぬこと',
                      hintStyle: TextStyle(
                          color: palette.onSurfaceFaintest, fontSize: 13),
                      filled: true,
                      fillColor: palette.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: palette.readable(const Color(0xFF90A4AE))),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: palette.readable(const Color(0xFF90A4AE)),
                            width: 2),
                      ),
                      counterStyle:
                          TextStyle(color: palette.onSurfaceFaintest),
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
                        Text(
                          '戒めを刻むと 知恵ポイント +1',
                          style: TextStyle(
                            color: palette.readable(const Color(0xFF90A4AE)),
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
                                  color: _onFilledButton,
                                ),
                              )
                            : const Text('💧',
                                style: TextStyle(fontSize: 18)),
                        label: const Text('戒めを刻む'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF37474F),
                          foregroundColor: _onFilledButton,
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
