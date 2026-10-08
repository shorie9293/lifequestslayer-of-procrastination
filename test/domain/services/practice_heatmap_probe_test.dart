// 親探針（イシコリドメ）: 勤行ヒートマップの合成不変条件。
// 眷属の試練は個別操作を撃つため、セル一意性・総和保存という構造の不変条件を親が撃つ。
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/services/practice_heatmap_service.dart';

PracticeLog log(DateTime updatedAt, int count) =>
    PracticeLog(date: updatedAt, count: count, updatedAt: updatedAt);

void main() {
  group('PracticeHeatmapService 親探針（不変条件）', () {
    final logs = [
      log(DateTime(2026, 9, 14, 7), 2), // 月 早朝? 7時→午前
      log(DateTime(2026, 9, 15, 3), 1), // 火 早朝
      log(DateTime(2026, 9, 16, 14), 5), // 水 午後
      log(DateTime(2026, 9, 20, 22), 3), // 日 夜
      log(DateTime(2026, 9, 22, 9), 4), // 火 午前
    ];
    final cells = PracticeHeatmapService.build(logs);

    test('セルは28件で (weekday,band) の組が一意', () {
      expect(cells.length, 28);
      final keys = cells.map((c) => '${c.weekday}_${c.band}').toSet();
      expect(keys.length, 28, reason: '同一セルの重複は構造欠陥');
    });

    test('総和は入力 count の合計に一致する（集計漏れ・二重計上なし）', () {
      expect(PracticeHeatmapService.totalPractice(cells), 2 + 1 + 5 + 3 + 4);
    });

    test('busiestBand の同数タイブレークは band 昇順（早朝が勝つ）', () {
      final tie = PracticeHeatmapService.build([
        log(DateTime(2026, 9, 14, 3), 2), // 早朝 band0
        log(DateTime(2026, 9, 15, 9), 2), // 午前 band1
      ]);
      expect(PracticeHeatmapService.busiestBand(tie), '早朝');
    });

    test('分類は updatedAt の時刻で行われ date(00:00正規化) に引きずられない', () {
      // date は同一日でも updatedAt が深夜なら band0 に入る
      final late = PracticeHeatmapService.build([
        log(DateTime(2026, 9, 14, 23), 1),
      ]);
      final cell = PracticeHeatmapService.cellOf(
        late,
        weekday: DateTime(2026, 9, 14, 23).weekday,
        band: 3,
      );
      expect(cell!.count, 1);
    });
  });
}
