import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_title_encyclopedia_screen.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 称号セクション
class TitleSection extends StatelessWidget {
  final Player player;
  final PlayerViewModel viewModel;

  const TitleSection({
    super.key,
    required this.player,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final cardColor =
        palette.isLight ? palette.cardBackgroundStrong : Colors.black54;
    final titleProgress = viewModel.titleProgressList;
    final unlockedCount = titleProgress.where((e) => e.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.military_tech, color: palette.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Text("称号セット (EXP+5%ボーナス)",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.onSurface)),
            ),
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'cross_app_title_encyclopedia'),
              label: 'クロスアプリ称号図鑑を開く',
              child: IconButton(
                key: AppKeys.crossAppTitleEncyclopediaEntry,
                tooltip: 'クロスアプリ称号図鑑',
                icon: Icon(Icons.menu_book, color: palette.onSurface),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CrossAppTitleEncyclopediaScreen(
                        ownedTitles: player.titles,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 現在装備中
        Card(
          color: cardColor,
          child: ListTile(
            title: Text(player.equippedTitle ?? "称号なし",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.readable(Colors.orange))),
            subtitle: const Text("現在装備中の称号"),
            trailing: SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(
                  SemanticTypes.button, 'change_title'),
              label: '称号を変更する',
              child: ElevatedButton(
                // ライトでは既定の前景色（primary=金 #D4A038）が淡色地に沈む（実測 1.95:1）。
                // ダークは既定のまま（見た目不変）。
                style: palette.isLight
                    ? ElevatedButton.styleFrom(
                        backgroundColor: palette.cardBackgroundStrong,
                        foregroundColor: palette.onSurface,
                      )
                    : null,
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
            backgroundColor: palette.cardBackgroundStrong,
            collapsedBackgroundColor: palette.cardBackgroundStrong,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            collapsedShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(
              "📜 称号アーカイブ  $unlockedCount / ${kAllTitles.length}",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: palette.onSurface),
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
                  context.read<PlayerViewModel>().save();
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
    final palette = GamePalette.of(context);
    final accentOrange = palette.readable(Colors.orange);
    final accentAmber = palette.readable(Colors.amber);

    return Card(
      color: palette.isLight ? palette.cardBackgroundStrong : Colors.black45,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isUnlocked
              ? Colors.amber.withValues(alpha: 0.6)
              : palette.border,
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
                  color: isUnlocked ? accentAmber : palette.onSurfaceFaintest,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "【${def.id}】",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked
                          ? accentOrange
                          : palette.onSurfaceFaintest,
                    ),
                  ),
                ),
                if (isEquipped)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: accentOrange, width: 1),
                    ),
                    child: Text("装備中",
                        style:
                            TextStyle(fontSize: 10, color: accentOrange)),
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
                      child: Text("装備",
                          style: TextStyle(color: accentAmber)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              def.condition,
              style: TextStyle(fontSize: 11, color: palette.onSurfaceFaint),
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progressRate,
                minHeight: 6,
                backgroundColor: palette.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNearlyDone
                      ? palette.readable(Colors.orangeAccent)
                      : accentAmber,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "$currentProgress / ${def.requiredCount}",
                style:
                    TextStyle(fontSize: 10, color: palette.onSurfaceFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTitleSelectDialog(BuildContext context) {
    final palette = GamePalette.of(context);
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
                            ? palette.readable(Colors.orange)
                            : palette.onSurface,
                      ),
                    ),
                    onTap: () {
                      viewModel.equipTitle(t); context.read<PlayerViewModel>().save();
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
