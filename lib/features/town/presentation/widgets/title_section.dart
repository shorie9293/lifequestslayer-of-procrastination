import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';

/// 称号セクション
class TitleSection extends StatelessWidget {
  final Player player;
  final GameViewModel viewModel;

  const TitleSection({
    super.key,
    required this.player,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final titleProgress = viewModel.titleProgressList;
    final unlockedCount = titleProgress.where((e) => e.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.military_tech, color: Colors.white),
            SizedBox(width: 8),
            Text("称号セット (EXP+5%ボーナス)",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        // 現在装備中
        Card(
          color: Colors.black54,
          child: ListTile(
            title: Text(player.equippedTitle ?? "称号なし",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
            subtitle: const Text("現在装備中の称号"),
            trailing: SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'change_title'),
              label: '称号を変更する',
              child: ElevatedButton(
                child: const Text("変更する"),
                onPressed: () =>
                    _showTitleSelectDialog(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 称号アーカイブ（進捗バー付き）
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.black38,
            collapsedBackgroundColor: Colors.black38,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            collapsedShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(
              "📜 称号アーカイブ  $unlockedCount / ${kAllTitles.length}",
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            children: titleProgress.map((entry) {
              return _buildTitleProgressCard(
                context: context,
                def: entry.def,
                isUnlocked: entry.isUnlocked,
                currentProgress: entry.progress,
                isEquipped: player.equippedTitle == entry.def.id,
                onEquip: () {
                  viewModel.equipTitle(entry.def.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("【${entry.def.id}】を装備した！")),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleProgressCard({
    required BuildContext context,
    required TitleDefinition def,
    required bool isUnlocked,
    required int currentProgress,
    required bool isEquipped,
    required VoidCallback onEquip,
  }) {
    final progressRate = (currentProgress / def.requiredCount).clamp(0.0, 1.0);
    final isNearlyDone = progressRate >= 0.9;

    return Card(
      color: Colors.black45,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isUnlocked
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.white12,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUnlocked ? Icons.military_tech : Icons.lock_outline,
                  color: isUnlocked ? Colors.amber : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "【${def.id}】",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.orange : Colors.white38,
                    ),
                  ),
                ),
                if (isEquipped)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: const Text("装備中",
                        style:
                            TextStyle(fontSize: 10, color: Colors.orange)),
                  )
                else if (isUnlocked)
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'equip_title_${def.id}'),
                    label: '称号【${def.id}】を装備',
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onEquip,
                      child: const Text("装備",
                          style: TextStyle(color: Colors.amber)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              def.condition,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progressRate,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNearlyDone ? Colors.orangeAccent : Colors.amber,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "$currentProgress / ${def.requiredCount}",
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTitleSelectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        List<String> titles = ["", ...player.titles];
        return AlertDialog(
          key: AppKeys.townTitleSelectDialog,
          title: const Text("称号一覧"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: titles.length,
              itemBuilder: (context, index) {
                final t = titles[index];
                return SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.listItem, 'select_title_$index'),
                  label: t.isEmpty ? "称号を外す" : t,
                  child: ListTile(
                    title: Text(
                      t.isEmpty ? "称号を外す" : t,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t == player.equippedTitle
                            ? Colors.orange
                            : Colors.white,
                      ),
                    ),
                    onTap: () {
                      viewModel.equipTitle(t);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
