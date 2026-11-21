import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/services/practice_heatmap_service.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// 勤行の時間帯×曜日ヒートマップ（Provider非依存・試練可能）。
///
/// [logs] を [PracticeHeatmapService] で 7曜日×4時間帯の 28 セルへ集計し、
/// 濃淡で勤行の分布を俯瞰する。時刻集計は logs の [PracticeLog.updatedAt]
/// のみから行い、DateTime.now を直読みしない。
class PracticeHeatmapView extends StatelessWidget {
  /// 集計対象の勤行ログ。
  final List<PracticeLog> logs;

  const PracticeHeatmapView({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final cells = PracticeHeatmapService.build(logs);
    final maxCount = PracticeHeatmapService.maxCount(cells);
    final total = PracticeHeatmapService.totalPractice(cells);
    final busiest = PracticeHeatmapService.busiestBand(cells);

    return Card(
      key: const Key('practice_heatmap_section'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏰ 勤行ヒートマップ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (busiest == null)
              Padding(
                key: const Key('practice_heatmap_empty'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'まだ記録がありません',
                  style: TextStyle(
                      fontSize: 13, color: palette.readable(Colors.grey)),
                ),
              )
            else ...[
              Text(
                '通算 $total回',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '一番多い時間帯: $busiest',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              _grid(context, cells, maxCount),
              const SizedBox(height: 12),
              const _Legend(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<PracticeHeatmapCell> cells, int maxCount) {
    final palette = GamePalette.of(context);
    final labelStyle = TextStyle(
        fontSize: 10, color: palette.readable(Colors.grey));
    // 列ヘッダ（時間帯）
    final header = <Widget>[
      const SizedBox(width: 20),
      for (var b = 0; b < PracticeHeatmapService.bands; b++)
        Expanded(
          child: Center(
            child: Text(
              PracticeHeatmapService.bandLabel(b),
              style: labelStyle,
            ),
          ),
        ),
    ];

    final rows = <Widget>[
      Row(children: header),
      const SizedBox(height: 4),
      for (var w = 1; w <= PracticeHeatmapService.weekdays; w++)
        Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                PracticeHeatmapService.weekdayLabel(w),
                style: labelStyle,
              ),
            ),
            for (var b = 0; b < PracticeHeatmapService.bands; b++)
              Expanded(child: _cell(context, cells, w, b, maxCount)),
          ],
        ),
    ];

    return Column(children: rows);
  }

  Widget _cell(BuildContext context, List<PracticeHeatmapCell> cells,
      int weekday, int band, int maxCount) {
    final cell = PracticeHeatmapService.cellOf(
      cells,
      weekday: weekday,
      band: band,
    );
    final count = cell?.count ?? 0;
    final intensity = PracticeHeatmapService.intensity(
      cell ?? PracticeHeatmapCell(weekday: weekday, band: band, count: 0),
      maxCount,
    );
    // alpha: 0 なら透明、>0 は 0.2〜1.0 に clamp して薄っすら見えるようにする。
    final alpha = count <= 0
        ? 0.0
        : (0.2 + intensity * 0.8).clamp(0.2, 1.0);
    // セル地（半透明の緑）を和紙白に合成した実効地で文字色を解決する。
    // ダークは従来の白／黒87 をそのまま保つ（見た目不変）。
    final palette = GamePalette.of(context);
    final preferred = intensity > 0.5 ? Colors.white : Colors.black87;
    final cellTextColor = palette.isLight
        ? palette.readableOn(
            preferred,
            Color.alphaBlend(
              const Color(0xFF4CAF50).withValues(alpha: alpha),
              const Color(0xFFF4F1E6),
            ),
            minRatio: 4.5,
          )
        : preferred;
    return Padding(
      key: Key('practice_heatmap_cell_${weekday}_$band'),
      padding: const EdgeInsets.all(1.5),
      child: SizedBox(
        height: 22,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(3),
          ),
          child: count > 0
              ? Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      color: cellTextColor,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// 濃淡の凡例（少 ←→ 多）。
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final labelStyle =
        TextStyle(fontSize: 10, color: palette.readable(Colors.grey));
    Widget swatch(double alpha) => Container(
          width: 16,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(2),
          ),
        );
    return Row(
      children: [
        Text('少', style: labelStyle),
        const SizedBox(width: 4),
        for (final a in [0.2, 0.4, 0.6, 0.8, 1.0]) ...[
          swatch(a),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 1),
        Text('多', style: labelStyle),
      ],
    );
  }
}