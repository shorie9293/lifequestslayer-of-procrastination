import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';

/// 宿屋（疲労軽減バフ）セクション
class InnSection extends StatelessWidget {
  final dynamic player;
  final dynamic viewModel;

  const InnSection({
    super.key,
    required this.player,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: AppKeys.townInnSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.hotel, color: Colors.white),
            SizedBox(width: 8),
            Text("宿屋 (疲労軽減バフ)",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        _buildInnItem(context, 0, "裏長屋の仮寝", 50, "翌日の疲労限界+2(微回復)"),
        _buildInnItem(context, 1, "旅籠の褥", 200, "翌日の疲労限界+5(中回復)"),
        _buildInnItem(context, 2, "将軍の御殿", 1000,
            "翌日の疲労限界+12(完全回復)"),
      ],
    );
  }

  Widget _buildInnItem(
      BuildContext context, int type, String name, int price, String desc) {
    return Card(
      color: Colors.black54,
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'inn_${type}_$price'),
          label: '$name ($price文)',
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bed, size: 16),
            label: Text("$price"),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  player.coins >= price ? Colors.amber[700] : Colors.grey,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (player.coins >= price) {
                _restAtInn(context, type, name, price);
              } else {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("文が足りないぜ")));
              }
            },
          ),
        ),
      ),
    );
  }

  void _restAtInn(
      BuildContext context, int type, String name, int price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: AppKeys.townInnConfirmDialog,
        title: const Text("宿泊確認"),
        content: Text(
            "「$name」に $price 文で泊まりますか？\n(※1日1回のみ。明日の疲労バフ上限を引き上げます)"),
        actions: [
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'cancel_inn'),
            label: '宿泊をやめる',
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("やめる"),
            ),
          ),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'confirm_inn'),
            label: '宿泊する',
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700]),
              onPressed: () {
                Navigator.pop(ctx);
                final err = viewModel.restAtInn(type);
                if (err != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(err)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "ぐっすり休んだ！明日はもっと頑張れそうだ！")),
                  );
                }
              },
              child: const Text("泊まる",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
