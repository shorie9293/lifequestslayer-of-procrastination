import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/habit_calendar.dart';

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
                      color: i == 0
                          ? Colors.red[300]
                          : i == 6
                              ? Colors.blue[300]
                              : Colors.grey[400],
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
    final keyStr =
        '${day.date.year.toString().padLeft(4, '0')}-'
        '${day.date.month.toString().padLeft(2, '0')}-'
        '${day.date.day.toString().padLeft(2, '0')}';
    final semantics = day.isActive
        ? '${day.date.month}月${day.date.day}日 勤行${day.activityCount}件'
        : '${day.date.month}月${day.date.day}日 未活動';

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
