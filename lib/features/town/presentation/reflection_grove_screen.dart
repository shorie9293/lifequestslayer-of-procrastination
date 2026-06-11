import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// 振り返りの杜 — 学びログと成長の可視化ダッシュボード。
///
/// - 累計統計（総振返り数／平均自己評価／AI推定分布）
/// - 自己評価 vs AI推定難易度 比較グラフ
/// - 難易度推移グラフ
/// - 振り返りログ時系列一覧
class ReflectionGroveScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ReflectionGroveScreen({super.key, this.onBack});

  @override
  State<ReflectionGroveScreen> createState() => _ReflectionGroveScreenState();
}

class _ReflectionGroveScreenState extends State<ReflectionGroveScreen> {
  final ReflectionRepository _repo = ReflectionRepository();
  List<Reflection> _reflections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _repo.getAll();
    if (mounted) {
      setState(() {
        _reflections = all;
        _loading = false;
      });
    }
  }

  // ── 統計計算 ──

  double get _avgSelfDifficulty {
    if (_reflections.isEmpty) return 0;
    return _reflections.map((r) => r.selfDifficulty).reduce((a, b) => a + b) /
        _reflections.length;
  }

  QuestRank get _mostCommonAiRank {
    if (_reflections.isEmpty) return QuestRank.B;
    final counts = <QuestRank, int>{};
    for (final r in _reflections) {
      counts[r.aiDifficulty] = (counts[r.aiDifficulty] ?? 0) + 1;
    }
    return counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  int get _currentStreak {
    if (_reflections.isEmpty) return 0;
    int streak = 1;
    final sorted = List<Reflection>.from(_reflections)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i - 1].date.difference(sorted[i].date).inDays;
      if (diff <= 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ── 比較用データ ──

  List<_ComparisonPoint> get _comparisonData {
    return _reflections
        .map((r) => _ComparisonPoint(
              date: r.date,
              label: _shortDate(r.date),
              selfDifficulty: r.selfDifficulty,
              aiDifficulty: r.aiDifficultyValue,
              content: r.content,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _shortDate(DateTime d) =>
      '${d.month}/${d.day}';

  String _rankLabel(QuestRank r) {
    switch (r) {
      case QuestRank.S:
        return 'S';
      case QuestRank.A:
        return 'A';
      case QuestRank.B:
        return 'B';
    }
  }

  Color _rankColor(QuestRank r) {
    switch (r) {
      case QuestRank.S:
        return const Color(0xFFFFD700);
      case QuestRank.A:
        return const Color(0xFFE67E22);
      case QuestRank.B:
        return const Color(0xFF3498DB);
    }
  }

  Color _selfDifficultyColor(int d) {
    switch (d) {
      case 1:
        return const Color(0xFF81C784);
      case 2:
        return const Color(0xFFAED581);
      case 3:
        return const Color(0xFFFFD54F);
      case 4:
        return const Color(0xFFFF8A65);
      case 5:
        return const Color(0xFFE57373);
      default:
        return const Color(0xFFFFD54F);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final comparisonData = _comparisonData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌳 振り返りの杜'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/home_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: _reflections.isEmpty
            ? _buildEmptyState()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 統計概要カード ──
                    _buildStatsRow(),
                    const SizedBox(height: 20),

                    // ── 自己評価 vs AI推定 比較グラフ ──
                    _buildSectionTitle('📊 自己評価 vs AI推定 難易度比較'),
                    const SizedBox(height: 8),
                    if (comparisonData.isNotEmpty)
                      _ComparisonChart(data: comparisonData),
                    const SizedBox(height: 24),

                    // ── 難易度分布 ──
                    _buildSectionTitle('📈 AI推定 難易度分布'),
                    const SizedBox(height: 8),
                    _AiRankDistribution(reflections: _reflections),
                    const SizedBox(height: 24),

                    // ── 難易度推移（直近10件） ──
                    if (comparisonData.length >= 2) ...[
                      _buildSectionTitle('📉 難易度の推移（直近）'),
                      const SizedBox(height: 8),
                      _TrendChart(
                        data: comparisonData.length > 10
                            ? comparisonData.sublist(comparisonData.length - 10)
                            : comparisonData,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── 振り返りログ一覧 ──
                    _buildSectionTitle(
                        '📜 学びの記録（${_reflections.length}件）'),
                    const SizedBox(height: 8),
                    ..._reflections.take(20).map((r) => _ReflectionTile(
                          reflection: r,
                          rankColor: _rankColor(r.aiDifficulty),
                          selfColor: _selfDifficultyColor(r.selfDifficulty),
                          rankLabel: _rankLabel(r.aiDifficulty),
                        )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🌳', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'まだ振り返りがありません。',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          SizedBox(height: 8),
          Text(
            '討伐後に「戦後の一息」で\n学びを記してみましょう。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4CAF50),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          label: '総振返り数',
          value: '${_reflections.length}',
          icon: '📝',
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '平均自己評価',
          value: _reflections.isEmpty ? '-' : _avgSelfDifficulty.toStringAsFixed(1),
          icon: '🎯',
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '最多AI推定',
          value: _reflections.isEmpty ? '-' : _rankLabel(_mostCommonAiRank),
          icon: '🔮',
          valueColor: _reflections.isEmpty ? null : _rankColor(_mostCommonAiRank),
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: '連続記録',
          value: '$_currentStreak日',
          icon: '🔥',
        ),
      ],
    );
  }
}

// ── 統計カード ──

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 比較グラフ用データポイント ──

class _ComparisonPoint {
  final DateTime date;
  final String label;
  final int selfDifficulty;
  final int aiDifficulty;
  final String content;

  const _ComparisonPoint({
    required this.date,
    required this.label,
    required this.selfDifficulty,
    required this.aiDifficulty,
    required this.content,
  });
}

// ── 自己評価 vs AI推定 比較棒グラフ (CustomPainter) ──

class _ComparisonChart extends StatelessWidget {
  final List<_ComparisonPoint> data;

  const _ComparisonChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final displayData =
        data.length > 15 ? data.sublist(data.length - 15) : data;
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: CustomPaint(
        painter: _ComparisonChartPainter(
          data: displayData,
          selfColor: const Color(0xFF4CAF50),
          aiColor: const Color(0xFFFFD700),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ComparisonChartPainter extends CustomPainter {
  final List<_ComparisonPoint> data;
  final Color selfColor;
  final Color aiColor;

  _ComparisonChartPainter({
    required this.data,
    required this.selfColor,
    required this.aiColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftPad = 30.0;
    const rightPad = 12.0;
    const topPad = 12.0;
    const bottomPad = 28.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    const maxVal = 5.0;
    final barGroupW = chartW / data.length;
    final barW = barGroupW * 0.35;

    // グリッド線
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 5; i++) {
      final y = topPad + chartH * (1 - i / maxVal);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartW, y),
        gridPaint,
      );
    }

    // Y軸ラベル
    const labelStyle = TextStyle(color: Colors.white38, fontSize: 9);
    for (int i = 1; i <= 5; i++) {
      final y = topPad + chartH * (1 - i / maxVal);
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // 棒
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final groupX = leftPad + barGroupW * i;

      // 自己評価（緑）
      final selfH = chartH * (d.selfDifficulty / maxVal);
      final selfRect = Rect.fromLTWH(
        groupX + barGroupW * 0.1,
        topPad + chartH - selfH,
        barW,
        selfH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(selfRect, const Radius.circular(3)),
        Paint()..color = selfColor.withValues(alpha: 0.8),
      );

      // AI推定（金）
      final aiH = chartH * (d.aiDifficulty / maxVal);
      final aiRect = Rect.fromLTWH(
        groupX + barGroupW * 0.1 + barW + 2,
        topPad + chartH - aiH,
        barW,
        aiH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(aiRect, const Radius.circular(3)),
        Paint()..color = aiColor.withValues(alpha: 0.8),
      );

      // X軸ラベル（3つおきに）
      if (data.length <= 10 || i % 3 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: d.label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(groupX + barGroupW / 2 - tp.width / 2, topPad + chartH + 4),
        );
      }
    }

    // 凡例
    final selfLabel = TextPainter(
      text: const TextSpan(
        text: '■ 自己評価',
        style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final aiLabel = TextPainter(
      text: const TextSpan(
        text: '■ AI推定',
        style: TextStyle(color: Color(0xFFFFD700), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    selfLabel.paint(canvas, const Offset(leftPad, 2));
    aiLabel.paint(canvas, Offset(leftPad + selfLabel.width + 16, 2));
  }

  @override
  bool shouldRepaint(covariant _ComparisonChartPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── AI推定難易度 分布円グラフ風 ──

class _AiRankDistribution extends StatelessWidget {
  final List<Reflection> reflections;

  const _AiRankDistribution({required this.reflections});

  @override
  Widget build(BuildContext context) {
    final total = reflections.length;
    final sCount = reflections.where((r) => r.aiDifficulty == QuestRank.S).length;
    final aCount = reflections.where((r) => r.aiDifficulty == QuestRank.A).length;
    final bCount = reflections.where((r) => r.aiDifficulty == QuestRank.B).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _RankBar(
            label: 'Sランク',
            count: sCount,
            total: total,
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 8),
          _RankBar(
            label: 'Aランク',
            count: aCount,
            total: total,
            color: const Color(0xFFE67E22),
          ),
          const SizedBox(height: 8),
          _RankBar(
            label: 'Bランク',
            count: bCount,
            total: total,
            color: const Color(0xFF3498DB),
          ),
        ],
      ),
    );
  }
}

class _RankBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _RankBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '$count件 (${(fraction * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ── 難易度推移 折れ線グラフ (CustomPainter) ──

class _TrendChart extends StatelessWidget {
  final List<_ComparisonPoint> data;

  const _TrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: CustomPaint(
        painter: _TrendChartPainter(data: data),
        size: Size.infinite,
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<_ComparisonPoint> data;

  _TrendChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const leftPad = 30.0;
    const rightPad = 12.0;
    const topPad = 12.0;
    const bottomPad = 28.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    const maxVal = 5.0;

    // グリッド線
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 5; i++) {
      final y = topPad + chartH * (1 - i / maxVal);
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + chartW, y), gridPaint);
    }

    // 自己評価線
    final selfLinePaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final selfPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW * i / (data.length - 1));
      final y = topPad + chartH * (1 - data[i].selfDifficulty / maxVal);
      if (i == 0) {
        selfPath.moveTo(x, y);
      } else {
        selfPath.lineTo(x, y);
      }
    }
    canvas.drawPath(selfPath, selfLinePaint);

    // 自己評価ドット
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW * i / (data.length - 1));
      final y = topPad + chartH * (1 - data[i].selfDifficulty / maxVal);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = const Color(0xFF4CAF50),
      );
    }

    // AI推定線
    final aiLinePaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final aiPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW * i / (data.length - 1));
      final y = topPad + chartH * (1 - data[i].aiDifficulty / maxVal);
      if (i == 0) {
        aiPath.moveTo(x, y);
      } else {
        aiPath.lineTo(x, y);
      }
    }
    canvas.drawPath(aiPath, aiLinePaint);

    // AI推定ドット
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW * i / (data.length - 1));
      final y = topPad + chartH * (1 - data[i].aiDifficulty / maxVal);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = const Color(0xFFFFD700),
      );
    }

    // X軸ラベル
    for (int i = 0; i < data.length; i++) {
      if (data.length <= 8 || i % 2 == 0) {
        final x = leftPad + (chartW * i / (data.length - 1));
        final tp = TextPainter(
          text: TextSpan(
            text: data[i].label,
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, topPad + chartH + 4));
      }
    }

    // 凡例
    final selfLabel = TextPainter(
      text: const TextSpan(
        text: '─ 自己評価',
        style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final aiLabel = TextPainter(
      text: const TextSpan(
        text: '─ AI推定',
        style: TextStyle(color: Color(0xFFFFD700), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    selfLabel.paint(canvas, const Offset(leftPad, 2));
    aiLabel.paint(canvas, Offset(leftPad + selfLabel.width + 16, 2));
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 振り返りログ タイル ──

class _ReflectionTile extends StatelessWidget {
  final Reflection reflection;
  final Color rankColor;
  final Color selfColor;
  final String rankLabel;

  const _ReflectionTile({
    required this.reflection,
    required this.rankColor,
    required this.selfColor,
    required this.rankLabel,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${reflection.date.month}/${reflection.date.day} ${reflection.date.hour}:${reflection.date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 自己評価バッジ
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selfColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selfColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '自己: ${reflection.selfDifficulty}',
                  style: TextStyle(
                    color: selfColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // AI推定バッジ
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rankColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'AI: $rankLabel',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          if (reflection.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reflection.content,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
