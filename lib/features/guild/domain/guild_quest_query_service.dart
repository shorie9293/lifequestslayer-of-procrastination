import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';

/// 寄合所クエスト一覧の検索・絞り込み・並び替え（純粋関数のみ）
class GuildQuestQueryService {
  GuildQuestQueryService._();

  /// 検索語の正規化:
  /// trim → 全角英数字(U+FF01..U+FF5E)と全角スペース(U+3000)を半角へ
  /// → toLowerCase → 連続空白を単一化
  static String normalize(String input) {
    final sb = StringBuffer();
    for (final code in input.trim().runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) {
        sb.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        sb.write(' ');
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// クエスト名 か いずれかの札（タグ） に検索語を含む（正規化後の部分一致）。
  /// 空/空白のみの検索語なら true。
  static bool matchesText(Task task, String query) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    if (normalize(task.title).contains(q)) return true;
    return task.tags.any((tag) => normalize(tag).contains(q));
  }

  /// 状態で絞り込む判定（statuses が空なら true）。該当述語の OR。
  static bool matchesStatus(
    Task task,
    Set<GuildQuestStatusFilter> statuses,
    DateTime now,
  ) {
    if (statuses.isEmpty) return true;
    return statuses.any((s) {
      switch (s) {
        case GuildQuestStatusFilter.active:
          return task.status == TaskStatus.active && !task.isCompleted;
        case GuildQuestStatusFilter.overdue:
          final deadline = task.deadline;
          return deadline != null && deadline.isBefore(now);
        case GuildQuestStatusFilter.recurring:
          return task.repeatInterval != RepeatInterval.none ||
              task.repeatAfterDays != null;
      }
    });
  }

  /// 難易度で絞り込む判定（ranks が空なら true）
  static bool matchesRank(Task task, Set<QuestRank> ranks) {
    if (ranks.isEmpty) return true;
    return ranks.contains(task.rank);
  }

  /// 安定ソート（入力を破壊しない）。同時順位は id 昇順。null は常に末尾。
  static List<Task> sort(List<Task> tasks, GuildQuestSortOrder order) {
    int byId(Task a, Task b) => a.id.compareTo(b.id);

    int compare(Task a, Task b) {
      int r;
      switch (order) {
        case GuildQuestSortOrder.deadlineAsc:
          final ad = a.deadline;
          final bd = b.deadline;
          if (ad == null && bd == null) {
            r = 0;
          } else if (ad == null) {
            r = 1; // null は常に末尾
          } else if (bd == null) {
            r = -1;
          } else {
            r = ad.compareTo(bd);
          }
        case GuildQuestSortOrder.rankDesc:
          // QuestRank.values の index 昇順 = S → A → B
          r = a.rank.index.compareTo(b.rank.index);
          if (r != 0) return r;
          r = normalize(a.title).compareTo(normalize(b.title));
        case GuildQuestSortOrder.timeDesc:
          final at = a.targetTimeMinutes;
          final bt = b.targetTimeMinutes;
          if (at == null && bt == null) {
            r = 0;
          } else if (at == null) {
            r = 1; // null は常に末尾
          } else if (bt == null) {
            r = -1;
          } else {
            r = bt.compareTo(at); // 降順
          }
        case GuildQuestSortOrder.titleAsc:
          r = normalize(a.title).compareTo(normalize(b.title));
      }
      if (r != 0) return r;
      return byId(a, b);
    }

    final copy = List.of(tasks)..sort(compare);
    return copy;
  }

  /// 複合適用: text → status → rank → sort の順。now 省略時は DateTime.now()。
  static List<Task> apply(
    List<Task> tasks,
    GuildQuestQuery query, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    var result = tasks
        .where((task) => matchesText(task, query.text))
        .toList(growable: false);
    result = result
        .where((task) => matchesStatus(task, query.statuses, effectiveNow))
        .toList(growable: false);
    result = result
        .where((task) => matchesRank(task, query.ranks))
        .toList(growable: false);
    return sort(result, query.sortOrder);
  }
}