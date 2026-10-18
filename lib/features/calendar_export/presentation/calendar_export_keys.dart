import 'package:flutter/widgets.dart';

import 'package:rpg_todo/features/calendar_export/domain/task_calendar_export_service.dart';

/// カレンダー書き出し画面の試練用 Key（寄合所 AppKeys とは分離）。
class CalendarExportAppKeys {
  CalendarExportAppKeys._();

  static const Key screen = Key('screen_calendar_export');
  static const Key rangeChips = Key('bar_calendar_export_ranges');
  static const Key countLabel = Key('txt_calendar_export_count');
  static const Key previewList = Key('list_calendar_export_preview');
  static const Key exportButton = Key('btn_calendar_export');
  static const Key emptyState = Key('empty_calendar_export');

  static Key rangeChip(CalendarExportRange range) =>
      Key('chip_calendar_export_range_${range.name}');

  static Key previewItem(String uid) => Key('row_calendar_export_$uid');
}
