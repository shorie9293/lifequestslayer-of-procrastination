/// 冒険の戦績シェアカードのプレビュー描画。
library;

import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card.dart';

/// 称号・Lv・戦績行（0値は省略）を一枚のカードに描画する StatelessWidget。
class AdventureShareCardView extends StatelessWidget {
  final AdventureShareCard card;

  const AdventureShareCardView({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <String, int>{
      '総クエスト完了': card.totalTasksCompleted,
      'Sランク': card.totalSRankCompleted,
      '刻の番人討伐': card.wardenDefeated,
      '最長ストリーク': card.longestStreak,
      '振り返り': card.totalReflections,
    }..removeWhere((_, v) => v <= 0);

    return SizedBox(
      width: 360,
      child: Card(
        key: AppKeys.adventureShareCardView,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.rankLabel,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                card.levelLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const Text('これからの冒険にご期待あれ！')
              else
                for (final entry in rows.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value}'),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
