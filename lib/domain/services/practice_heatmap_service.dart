/// 勤行の時間帯×曜日ヒートマップ集計サービス（純粋ドメイン・状態なし）。
///
/// 各 [PracticeLog] を `updatedAt` の時刻から 4 時間帯 × 7 曜日のセルへ集計する。
/// [PracticeLog.date] は時刻が 00:00 に正規化されているため、時刻分類は必ず
/// [PracticeLog.updatedAt] を用いる。
library;

import 'package:rpg_todo/domain/models/practice_log.dart';

/// ヒートマップの 1 セル（曜日×時間帯）。
class PracticeHeatmapCell {
  /// 曜日（DateTime.weekday と同じ 1=月..7=日）。
  final int weekday;

  /// 時間帯（0=早朝, 1=午前, 2=午後, 3=夜）。
  final int band;

  /// セルに集計された勤行回数。
  final int count;

  const PracticeHeatmapCell({
    required this.weekday,
    required this.band,
    required this.count,
  });

  @override
  bool operator ==(Object other) =>
      other is PracticeHeatmapCell &&
      other.weekday == weekday &&
      other.band == band &&
      other.count == count;

  @override
  int get hashCode => Object.hash(weekday, band, count);

  @override
  String toString() => 'PracticeHeatmapCell(w=$weekday, b=$band, n=$count)';
}

/// 勤行ログを時間帯×曜日ヒートマップに集計する。
class PracticeHeatmapService {
  /// 曜日数。
  static const int weekdays = 7;

  /// 時間帯数。
  static const int bands = 4;

  /// [logs] を 7曜日×4時間帯=28 セルに集計する。
  ///
  /// セル順は weekday 昇順 → band 昇順。入力リストは破壊しない。
  static List<PracticeHeatmapCell> build(List<PracticeLog> logs) {
    final grid = List.generate(
      weekdays,
      (_) => List.filled(bands, 0, growable: false),
      growable: false,
    );
    for (final log in logs) {
      final hour = log.updatedAt.hour;
      final band = hour < 6
          ? 0
          : hour < 12
              ? 1
              : hour < 18
                  ? 2
                  : 3;
      grid[log.updatedAt.weekday - 1][band] += log.count;
    }
    final cells = <PracticeHeatmapCell>[];
    for (var w = 0; w < weekdays; w++) {
      for (var b = 0; b < bands; b++) {
        cells.add(PracticeHeatmapCell(
          weekday: w + 1,
          band: b,
          count: grid[w][b],
        ));
      }
    }
    return cells;
  }

  /// 指定セルを検索する。範囲外なら null。
  static PracticeHeatmapCell? cellOf(
    List<PracticeHeatmapCell> cells, {
    required int weekday,
    required int band,
  }) {
    for (final c in cells) {
      if (c.weekday == weekday && c.band == band) return c;
    }
    return null;
  }

  /// 全セルの回数総和。
  static int totalPractice(List<PracticeHeatmapCell> cells) =>
      cells.fold(0, (sum, c) => sum + c.count);

  /// 最大セルの回数（空なら 0）。
  static int maxCount(List<PracticeHeatmapCell> cells) {
    var max = 0;
    for (final c in cells) {
      if (c.count > max) max = c.count;
    }
    return max;
  }

  /// [cell] の回数を [max] 基準で 0..1 に正規化する。[max] <= 0 なら 0.0。
  static double intensity(PracticeHeatmapCell cell, int max) {
    if (max <= 0) return 0.0;
    return cell.count / max;
  }

  /// 時間帯ごとの合計が最大のラベル。同数は band 昇順、全 0 なら null。
  static String? busiestBand(List<PracticeHeatmapCell> cells) {
    final totals = List.filled(bands, 0);
    for (final c in cells) {
      totals[c.band] += c.count;
    }
    var best = -1;
    var bestTotal = 0;
    for (var b = 0; b < bands; b++) {
      if (totals[b] > bestTotal) {
        bestTotal = totals[b];
        best = b;
      }
    }
    if (best < 0) return null;
    return bandLabel(best);
  }

  /// 時間帯ラベル。
  static String bandLabel(int band) {
    switch (band) {
      case 0:
        return '早朝';
      case 1:
        return '午前';
      case 2:
        return '午後';
      case 3:
        return '夜';
      default:
        throw ArgumentError.value(band, 'band', 'must be 0..3');
    }
  }

  /// 曜日ラベル（1=月..7=日）。
  static String weekdayLabel(int weekday) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday', 'must be 1..7');
    }
    return labels[weekday - 1];
  }
}