import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/services/practice_heatmap_service.dart';

void main() {
  DateTime at(int weekday, int hour, {int day = 5}) {
    // 2026-10-05 は月曜日(weekday=1)。weekday(1=月..7=日) に応じて日をずらす。
    return DateTime(2026, 10, day + (weekday - 1), hour, 30);
  }

  group('PracticeHeatmapService.build', () {
    test('空ログなら28セル全て0で返す', () {
      final cells = PracticeHeatmapService.build(const []);
      expect(cells.length, 28);
      expect(cells.every((c) => c.count == 0), isTrue);
    });

    test('updatedAt の時刻から時間帯と曜日に集計する', () {
      final cells = PracticeHeatmapService.build([
        PracticeLog(date: at(1, 9), count: 2, updatedAt: at(1, 9)),
      ]);
      final cell = PracticeHeatmapService.cellOf(cells, weekday: 1, band: 1);
      expect(cell, isNotNull);
      expect(cell!.count, 2);
      // 他のセルは空
      expect(
        cells.where((c) => c.count > 0).length,
        1,
        reason: '同一セルのみ加算される',
      );
    });

    test('同一セル（同曜日・同時間帯）は合算する', () {
      final cells = PracticeHeatmapService.build([
        PracticeLog(date: at(1, 8), count: 1, updatedAt: at(1, 8)),
        PracticeLog(date: at(1, 11), count: 3, updatedAt: at(1, 11)),
      ]);
      expect(
        PracticeHeatmapService.cellOf(cells, weekday: 1, band: 1)!.count,
        4,
      );
    });

    test('時刻帯の境界: 6時は午前・18時は夜に分類する', () {
      final cells = PracticeHeatmapService.build([
        PracticeLog(date: at(2, 6), updatedAt: at(2, 6)),
        PracticeLog(date: at(2, 18), updatedAt: at(2, 18)),
        PracticeLog(date: at(2, 5), updatedAt: at(2, 5)),
        PracticeLog(date: at(2, 17), updatedAt: at(2, 17)),
        PracticeLog(date: at(2, 23), updatedAt: at(2, 23)),
        PracticeLog(date: at(2, 0), updatedAt: at(2, 0)),
      ]);
      expect(PracticeHeatmapService.cellOf(cells, weekday: 2, band: 0)!.count, 2);
      expect(PracticeHeatmapService.cellOf(cells, weekday: 2, band: 1)!.count, 1);
      expect(PracticeHeatmapService.cellOf(cells, weekday: 2, band: 2)!.count, 1);
      expect(PracticeHeatmapService.cellOf(cells, weekday: 2, band: 3)!.count, 2);
    });

    test('セルは曜日昇順→時間帯昇順に整列する', () {
      final cells = PracticeHeatmapService.build([
        PracticeLog(date: at(7, 20), updatedAt: at(7, 20)),
        PracticeLog(date: at(1, 8), updatedAt: at(1, 8)),
      ]);
      final nonEmpty = cells.where((c) => c.count > 0).toList();
      expect(nonEmpty.length, 2);
      expect(nonEmpty[0].weekday, 1);
      expect(nonEmpty[1].weekday, 7);
      final mondayCells = cells.where((c) => c.weekday == 1).toList();
      expect(
        mondayCells.map((c) => c.band).toList(),
        mondayCells.map((c) => c.band).toList()..sort(),
        reason: '同曜日内は時間帯昇順',
      );
    });

    test('入力リストを破壊しない', () {
      final logs = [PracticeLog(date: at(3, 13), updatedAt: at(3, 13))];
      final before = List.of(logs);
      PracticeHeatmapService.build(logs);
      expect(logs.length, before.length);
    });
  });

  group('PracticeHeatmapService 集計ヘルパ', () {
    final logs = [
      PracticeLog(date: at(1, 9), count: 5, updatedAt: at(1, 9)),
      PracticeLog(date: at(4, 21), count: 2, updatedAt: at(4, 21)),
      PracticeLog(date: at(4, 9), count: 1, updatedAt: at(4, 9)),
    ];
    final cells = PracticeHeatmapService.build(logs);

    test('totalPractice は回数の総和', () {
      expect(PracticeHeatmapService.totalPractice(cells), 8);
    });

    test('maxCount は最大セルの回数', () {
      expect(PracticeHeatmapService.maxCount(cells), 5);
    });

    test('intensity は0..1に正規化（max=0は0）', () {
      final c = PracticeHeatmapService.cellOf(cells, weekday: 1, band: 1)!;
      expect(PracticeHeatmapService.intensity(c, 5), 1.0);
      expect(PracticeHeatmapService.intensity(c, 10), 0.5);
      expect(PracticeHeatmapService.intensity(c, 0), 0.0);
    });

    test('busiestBand は最大の時間帯ラベル（同数はband昇順）', () {
      // band1(午前): 5+1=6, band3(夜): 2 → 午前
      expect(PracticeHeatmapService.busiestBand(cells), '午前');
      final tie = PracticeHeatmapService.build([
        PracticeLog(date: at(1, 9), updatedAt: at(1, 9)),
        PracticeLog(date: at(2, 21), updatedAt: at(2, 21)),
      ]);
      expect(PracticeHeatmapService.busiestBand(tie), '午前');
    });

    test('busiestBand は全セル0なら null', () {
      expect(
        PracticeHeatmapService.busiestBand(
          PracticeHeatmapService.build(const []),
        ),
        isNull,
      );
    });

    test('bandLabel / weekdayLabel', () {
      expect(PracticeHeatmapService.bandLabel(0), '早朝');
      expect(PracticeHeatmapService.bandLabel(1), '午前');
      expect(PracticeHeatmapService.bandLabel(2), '午後');
      expect(PracticeHeatmapService.bandLabel(3), '夜');
      expect(PracticeHeatmapService.weekdayLabel(1), '月');
      expect(PracticeHeatmapService.weekdayLabel(7), '日');
    });
  });
}
