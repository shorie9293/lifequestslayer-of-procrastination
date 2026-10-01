import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart_service.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class AdventurerChartScreen extends StatelessWidget {
  final AdventurerChart? chart; // 注入（試練用）。null なら player から build
  final Player? player; // 注入。null なら context.watch<PlayerViewModel>().player

  const AdventurerChartScreen({super.key, this.chart, this.player});

  AdventurerChart _resolve(BuildContext context) {
    if (chart != null) return chart!;
    final p = player ?? context.watch<PlayerViewModel>().player;
    return AdventurerChartService.build(p);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolve(context);
    return Scaffold(
      key: AppKeys.adventurerChartScreen,
      appBar: AppBar(title: const Text('冒険者カルテ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RankCard(chart: resolved),
          const SizedBox(height: 16),
          for (final group in resolved.groups) ...[
            _GroupSection(group: group),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final AdventurerChart chart;
  const _RankCard({required this.chart});

  @override
  Widget build(BuildContext context) {
    final totalTasks = chart.allEntries.firstWhere((e) => e.id == 'total_tasks').value;
    final next = AdventurerChartService.nextRankThreshold(totalTasks);
    final progress = AdventurerChartService.progressToNextRank(totalTasks);
    final isMax = next == null;
    return Card(
      key: AppKeys.adventurerRankCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chart.rankLabel,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(isMax ? '最高到達点' : '次の称号まで ${next}件'),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final AdventurerStatGroup group;
  const _GroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: AppKeys.adventurerGroupSection(group.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(group.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text('${group.totalValue}'),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in group.entries)
              ListTile(
                key: AppKeys.adventurerStatRow(entry.id),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(entry.emoji, style: const TextStyle(fontSize: 18)),
                title: Text(entry.label),
                trailing: Text(entry.displayValue),
              ),
          ],
        ),
      ),
    );
  }
}
