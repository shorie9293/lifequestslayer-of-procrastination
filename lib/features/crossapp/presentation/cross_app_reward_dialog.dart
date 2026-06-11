import 'package:flutter/material.dart';

/// tsundoku-quest 連携報酬の通知ダイアログ
///
/// アプリ起動時・復帰時にクロスアプリ報酬を処理した結果を表示する。
class CrossAppRewardDialog extends StatelessWidget {
  final int totalCoins;
  final int totalExp;
  final List<String> newTitles;

  const CrossAppRewardDialog({
    super.key,
    required this.totalCoins,
    required this.totalExp,
    required this.newTitles,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Text('🏅'),
          SizedBox(width: 8),
          Text(
            'tsundoku-quest 連携報酬',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (newTitles.isNotEmpty) ...[
            const Text(
              '📜 新たな称号を獲得！',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            ...newTitles.map(
              (title) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  '　『$title』',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (totalCoins > 0) ...[
            Text('💰 コイン: +$totalCoins'),
            const SizedBox(height: 4),
          ],
          if (totalExp > 0) ...[
            Text('✨ EXP: +$totalExp'),
            const SizedBox(height: 4),
          ],
          if (totalCoins == 0 && totalExp == 0 && newTitles.isEmpty)
            const Text('今回の報酬はありませんでした。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('受け取る'),
        ),
      ],
    );
  }

  /// 報酬がある場合のみダイアログを表示
  static Future<void> showIfHasRewards(
    BuildContext context, {
    required int totalCoins,
    required int totalExp,
    required List<String> newTitles,
  }) {
    if (totalCoins == 0 && totalExp == 0 && newTitles.isEmpty) {
      return Future.value();
    }
    return showDialog(
      context: context,
      builder: (_) => CrossAppRewardDialog(
        totalCoins: totalCoins,
        totalExp: totalExp,
        newTitles: newTitles,
      ),
    );
  }
}
