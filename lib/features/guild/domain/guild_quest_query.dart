import 'package:flutter/foundation.dart';

import 'package:rpg_todo/domain/models/task.dart';

/// 寄合所クエストの状態絞り込み
enum GuildQuestStatusFilter {
  active('挑戦中'),
  overdue('期日超過'),
  recurring('繰り返し');

  const GuildQuestStatusFilter(this.label);
  final String label;
}

/// 寄合所クエストの並び替え順
enum GuildQuestSortOrder {
  deadlineAsc('期限が近い順'),
  rankDesc('難易度が高い順'),
  timeDesc('見積もりが長い順'),
  titleAsc('名前順');

  const GuildQuestSortOrder(this.label);
  final String label;
}

/// 寄合所クエスト一覧の検索・絞り込み条件（不変）
@immutable
class GuildQuestQuery {
  final String text;

  /// 絞り込む状態。空集合 = 全状態
  final Set<GuildQuestStatusFilter> statuses;

  /// 絞り込む難易度。空集合 = 全難易度
  final Set<QuestRank> ranks;
  final GuildQuestSortOrder sortOrder;

  const GuildQuestQuery({
    this.text = '',
    this.statuses = const {},
    this.ranks = const {},
    this.sortOrder = GuildQuestSortOrder.deadlineAsc,
  });

  /// 既定値そのものか
  bool get isDefault =>
      text.trim().isEmpty &&
      statuses.isEmpty &&
      ranks.isEmpty &&
      sortOrder == GuildQuestSortOrder.deadlineAsc;

  /// 有効な絞り込み条件の数（テキスト + statuses + ranks + 既定以外のソート）
  int get activeFilterCount =>
      (text.trim().isEmpty ? 0 : 1) +
      statuses.length +
      ranks.length +
      (sortOrder == GuildQuestSortOrder.deadlineAsc ? 0 : 1);

  GuildQuestQuery copyWith({
    String? text,
    Set<GuildQuestStatusFilter>? statuses,
    Set<QuestRank>? ranks,
    GuildQuestSortOrder? sortOrder,
  }) {
    return GuildQuestQuery(
      text: text ?? this.text,
      statuses: statuses ?? this.statuses,
      ranks: ranks ?? this.ranks,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GuildQuestQuery &&
        other.text == text &&
        setEquals(other.statuses, statuses) &&
        setEquals(other.ranks, ranks) &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAllUnordered(statuses),
        Object.hashAllUnordered(ranks),
        sortOrder,
      );
}