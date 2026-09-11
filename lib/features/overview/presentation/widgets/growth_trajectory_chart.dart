import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/growth_trajectory.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/services/growth_trajectory_service.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// 成長軌跡の量的可視化（道標§五 #26）。
///
/// 「勤行完了数」「討伐勝利数」を月別・累積で折れ線表示する。
/// レベル/EXPの履歴は保持していないため、現在値はヘッダにスナップショット表示する。
class GrowthTrajectoryChart extends StatelessWidget {
  /// 昇順（古い月→新しい月）の月次ポイント。
  final GrowthTrajectory trajectory;

  /// true: 累積線 / false: 月別の活動量。
  final bool showCumulative;

  final double height;

  const GrowthTrajectoryChart({
    super.key,
    required this.trajectory,
    this.showCumulative = true,
    this.height = 220,
  });

  static const Color questColor = Color(0xFFE8B84B);
  static const Color defeatColor = Color(0xFF7FA8E8);

  @override
  Widget build(BuildContext context) {
    final points = trajectory.points;
    if (points.isEmpty || trajectory.isEmpty) {
      return SizedBox(
        key: const Key('growth_chart_empty'),
        height: height,
        child: const Center(child: Text('成長の記録がまだありません')),
      );
    }

    final questSpots = <FlSpot>[];
    final defeatSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      questSpots.add(FlSpot(
        i.toDouble(),
        (showCumulative ? p.cumulativeQuests : p.questsCompleted).toDouble(),
      ));
      defeatSpots.add(FlSpot(
        i.toDouble(),
        (showCumulative ? p.cumulativeDefeats : p.defeats).toDouble(),
      ));
    }

    final values = [
      ...questSpots.map((s) => s.y),
      ...defeatSpots.map((s) => s.y),
    ];
    var maxY = values.reduce((a, b) => a > b ? a : b);
    var minY = values.reduce((a, b) => a < b ? a : b);
    if (maxY == minY) {
      maxY += 1;
      minY = 0;
    } else {
      minY = 0;
    }
    final pad = (maxY - minY) * 0.15;
    maxY += pad;

    return Column(
      key: const Key('growth_chart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            key: const Key('growth_chart_canvas'),
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                _line(questSpots, questColor),
                _line(defeatSpots, defeatColor),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _interval(maxY),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: _interval(maxY),
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final step = points.length <= 6 ? 1 : 3;
                      if (index % step != 0 && index != points.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          points[index].label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: const [
            _Legend(color: questColor, label: '勤行完了'),
            _Legend(color: defeatColor, label: '討伐勝利'),
          ],
        ),
      ],
    );
  }

  static LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      barWidth: 2.5,
      color: color,
      dotData: FlDotData(show: spots.length <= 12),
      belowBarData: BarAreaData(show: false),
    );
  }

  static double _interval(double maxY) {
    if (maxY <= 5) return 1;
    if (maxY <= 20) return 5;
    return (maxY / 4).ceilToDouble();
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// 成長軌跡のタブ本体。月別/累積の切替とサマリを備える。
class GrowthTrajectoryView extends StatefulWidget {
  final GrowthTrajectory trajectory;

  /// 現在のレベル（スナップショット表示用）。
  final int level;

  /// 次レベルまでの現在EXP。
  final int exp;

  /// 次レベルまでの必要EXP。
  final int expToNextLevel;

  const GrowthTrajectoryView({
    super.key,
    required this.trajectory,
    this.level = 1,
    this.exp = 0,
    this.expToNextLevel = 0,
  });

  @override
  State<GrowthTrajectoryView> createState() => _GrowthTrajectoryViewState();
}

class _GrowthTrajectoryViewState extends State<GrowthTrajectoryView> {
  bool _cumulative = true;

  @override
  Widget build(BuildContext context) {
    final t = widget.trajectory;
    return ListView(
      key: const Key('growth_trajectory_view'),
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(t),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('表示', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            SegmentedButton<bool>(
              key: const Key('growth_mode_toggle'),
              segments: const [
                ButtonSegment(value: true, label: Text('累積')),
                ButtonSegment(value: false, label: Text('月別')),
              ],
              selected: {_cumulative},
              onSelectionChanged: (s) => setState(() => _cumulative = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GrowthTrajectoryChart(
          trajectory: t,
          showCumulative: _cumulative,
        ),
        const SizedBox(height: 16),
        const Text('月別の歩み', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...t.points.reversed.map(
          (p) => ListTile(
            dense: true,
            leading: Text(p.label, style: const TextStyle(fontSize: 12)),
            title: Text(
              '勤行 ${p.questsCompleted} ・ 討伐 ${p.defeats}',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: p.isEmpty
                ? null
                : Text(
                    '累積 ${p.cumulativeQuests + p.cumulativeDefeats}',
                    style: const TextStyle(fontSize: 11),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _headerCard(GrowthTrajectory t) {
    return Card(
      key: const Key('growth_header_card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '現在 Lv.${widget.level} ／ EXP ${widget.exp}/${widget.expToNextLevel}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _stat('累積 勤行', '${t.totalQuestsCompleted}'),
                _stat('累積 討伐', '${t.totalDefeats}'),
                _stat('活動月', '${t.activeMonths}/${t.windowMonths}'),
                _stat('最長連続', '${t.longestActiveStreak}か月'),
                _stat(
                  '最活動月',
                  t.bestMonth == null
                      ? '—'
                      : '${t.bestMonth!.year}/${t.bestMonth!.month}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 俯瞰の魔眼「成長」タブ。振り返りとクエスト履歴から成長軌跡を構築する。
class GrowthTrajectoryTab extends StatefulWidget {
  /// テスト用に注入可能な振り返りリポジトリ。
  final ReflectionRepository? repository;

  /// 基準日（テスト用。既定は現在時刻）。
  final DateTime? now;

  const GrowthTrajectoryTab({super.key, this.repository, this.now});

  @override
  State<GrowthTrajectoryTab> createState() => _GrowthTrajectoryTabState();
}

class _GrowthTrajectoryTabState extends State<GrowthTrajectoryTab> {
  late final ReflectionRepository _repo;
  List<Reflection> _reflections = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ReflectionRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _reflections = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tasks = context.watch<TaskViewModel>().tasks;
    final player = context.watch<PlayerViewModel>().player;
    final trajectory = GrowthTrajectoryService.compute(
      tasks: tasks,
      reflections: _reflections,
      now: widget.now ?? DateTime.now(),
    );

    return GrowthTrajectoryView(
      trajectory: trajectory,
      level: player.level,
      exp: player.currentExp,
      expToNextLevel: player.expToNextLevel,
    );
  }
}
