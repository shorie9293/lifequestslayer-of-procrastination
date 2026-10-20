import 'package:flutter/widgets.dart';

import '../domain/quiet_hours.dart';

/// 静穏時間（おやすみモード）画面の試練用 Key。
/// 他画面の [AppKeys] と重複しないよう独立ファイルに分離する。
abstract final class QuietHoursAppKeys {
  static const Key screen = Key('screen_quiet_hours');
  static const Key entry = Key('btn_quiet_hours_entry');
  static const Key toggle = Key('tgl_quiet_hours_enabled');
  static const Key startHour = Key('dd_quiet_hours_start_hour');
  static const Key startMinute = Key('dd_quiet_hours_start_minute');
  static const Key endHour = Key('dd_quiet_hours_end_hour');
  static const Key endMinute = Key('dd_quiet_hours_end_minute');
  static const Key preview = Key('txt_quiet_hours_preview');
  static const Key saveButton = Key('btn_quiet_hours_save');

  static Key policyRadio(QuietHoursPolicy policy) =>
      Key('radio_quiet_hours_${policy.storageKey}');
}
