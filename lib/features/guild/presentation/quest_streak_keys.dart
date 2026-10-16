import 'package:flutter/foundation.dart';

/// クエスト別ストリーク画面の試練用 Key 一式。
///
/// 既存 [AppKeys] には追記せず、本機能専用ファイルに分離する。
class QuestStreakKeys {
  const QuestStreakKeys._();

  /// ストリーク画面（Scaffold）。
  static const Key screen = Key('quest_streak_screen');

  /// サマリーカード。
  static const Key summaryCard = Key('quest_streak_summary_card');

  /// 該当0件・記録なしの空状態。
  static const Key emptyState = Key('quest_streak_empty_state');

  /// ストリーク一覧のリスト。
  static const Key list = Key('quest_streak_list');

  /// タイトル検索 TextField。
  static const Key searchField = Key('quest_streak_search_field');

  /// 「ボーナス中のみ」FilterChip。
  static const Key bonusFilterChip = Key('quest_streak_bonus_filter_chip');

  /// 寄合所オーバーフローメニューの入口項目（PopupMenuItem 内 Row 側）。
  static const Key guildEntry = Key('quest_streak_guild_entry');
}