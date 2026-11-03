import 'package:flutter/widgets.dart';

import 'package:rpg_todo/features/calendar_link/domain/calendar_import_service.dart';

/// カレンダー取り込み画面の試練用 Key（寄合所 AppKeys とは分離）。
class CalendarLinkAppKeys {
  CalendarLinkAppKeys._();

  static const Key screen = Key('screen_calendar_import');
  static const Key loading = Key('progress_calendar_import');
  static const Key permissionDenied = Key('txt_calendar_import_denied');
  static const Key unsupported = Key('txt_calendar_import_unsupported');
  static const Key errorState = Key('txt_calendar_import_error');
  static const Key retryButton = Key('btn_calendar_import_retry');
  static const Key rangeChips = Key('bar_calendar_import_ranges');
  static const Key countLabel = Key('txt_calendar_import_count');
  static const Key eventList = Key('list_calendar_import_events');
  static const Key emptyState = Key('empty_calendar_import');
  static const Key importButton = Key('btn_calendar_import');

  static Key rangeChip(CalendarImportRange range) =>
      Key('chip_calendar_import_range_${range.name}');

  static Key eventTile(String eventId) => Key('row_calendar_import_$eventId');
}
