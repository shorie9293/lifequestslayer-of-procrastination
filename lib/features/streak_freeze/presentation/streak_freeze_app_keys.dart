import 'package:flutter/widgets.dart';

/// お休み券画面（#153）の Key 集約。
///
/// 既存の [AppKeys] とは別ファイルに分離する（肥大化・不可視化の回避）。
class StreakFreezeKeys {
  const StreakFreezeKeys._();

  static const Key screen = Key('screen_streak_freeze');
  static const Key ticketCount = Key('txt_streak_freeze_tickets');
  static const Key useButton = Key('btn_streak_freeze_use');
  static const Key offerCard = Key('card_streak_freeze_offer');
  static const Key noOfferLabel = Key('txt_streak_freeze_no_offer');
  static const Key insufficientLabel = Key('txt_streak_freeze_insufficient');
  static const Key emptyHistory = Key('txt_streak_freeze_empty_history');

  /// 設定ハブからの導線。
  static const Key entryFromSettings = Key('btn_streak_freeze_entry');

  /// 使用履歴の行（[index] は新しい順）。
  static Key historyTile(int index) => Key('tile_streak_freeze_history_$index');
}
