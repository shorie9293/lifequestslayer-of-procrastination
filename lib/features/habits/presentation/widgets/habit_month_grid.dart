import 'package:flutter/material.dart';
import 'package:rpg_todo/core/time/local_calendar_date.dart';
import 'package:rpg_todo/domain/models/habit_calendar.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// 1か月分の勤行出席マップ（道標§五 #31）。
///
/// [HabitMonth.cells] を 7 列（日曜始まり）のグリッドで描画する。
/// null セルは月初の曜日合わせ・末尾パディングの空白。
class HabitMonthGrid extends StatelessWidget {
  final HabitMonth month;

  const HabitMonthGrid({super.key, required this.month});

  /// 活動日セルのアクセント色。
  static const Color activeColor = Color(0xFFE8B84B);

  /// 日曜始まりの曜日ラベル。
  static const List<String> weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    // 曜日ラベルの色はライトでは和紙白に沈むため、可読化してから使う
    // （実測: grey400=1.69:1 / red300=2.69:1 / blue300=2.00:1）。
    Color weekdayColor(int index) {
      final base = index == 0
          ? Colors.red[300]!
          : index == 6
              ? Colors.blue[300]!
              : Colors.grey[400]!;
      return palette.isLight ? palette.readable(base) : base;
    }

    return Column(
      key: const Key('habit_month_grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < weekdayLabels.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdayLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: weekdayColor(i),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final cell in month.cells)
              cell == null ? const SizedBox.shrink() : _dayCell(cell),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(HabitDay day) {
    // HabitCalendarService はローカル暦で日付を構築するが、将来 UTC 種別の
    // 日付が流入しても表示が崩れないよう正準関数を経由する（冪等）。
    final date = normalizeToLocal(day.date);
    final keyStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final semantics = day.isActive
        ? '${date.month}月${date.day}日 勤行${day.activityCount}件'
        : '${date.month}月${date.day}日 未活動';

    return Semantics(
      label: semantics,
      child: Container(
        key: Key('habit_day_$keyStr'),
        decoration: BoxDecoration(
          color: day.isActive ? activeColor : Colors.grey[850],
          shape: BoxShape.circle,
          border: day.isToday
              ? Border.all(color: Colors.amberAccent, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          day.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: day.isToday ? FontWeight.bold : FontWeight.normal,
            color: day.isActive ? Colors.black87 : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
