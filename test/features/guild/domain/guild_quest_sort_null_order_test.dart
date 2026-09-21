import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query_service.dart';

/// 親による回帰試練: null(期限/見積もり無し) は必ず末尾に来る。
/// id は uuid v4 で時系列性がないため id 順に依存してはならない。
Task _t(String id, {DateTime? deadline, int? minutes, QuestRank rank = QuestRank.B}) {
  return Task(
    id: id,
    title: id,
    rank: rank,
    deadline: deadline,
    targetTimeMinutes: minutes,
  );
}

void main() {
  final now = DateTime(2026, 9, 22, 6, 0);
  test('deadlineAsc: id が降順でも null 期限は末尾', () {
    final withDeadline = _t('zzz', deadline: now.add(const Duration(days: 1)));
    final noDeadline = _t('aaa');
    final sorted = GuildQuestQueryService.sort(
      [noDeadline, withDeadline],
      GuildQuestSortOrder.deadlineAsc,
    );
    expect(sorted.map((t) => t.id).toList(), ['zzz', 'aaa']);
  });

  test('timeDesc: id が降順でも 見積もり無しは末尾', () {
    final withTime = _t('zzz', minutes: 30);
    final noTime = _t('aaa');
    final sorted = GuildQuestQueryService.sort(
      [noTime, withTime],
      GuildQuestSortOrder.timeDesc,
    );
    expect(sorted.map((t) => t.id).toList(), ['zzz', 'aaa']);
  });

  test('deadlineAsc: null が複数でも非nullが先頭', () {
    final a = _t('b', deadline: now.add(const Duration(days: 2)));
    final b = _t('a');
    final c = _t('c');
    final sorted = GuildQuestQueryService.sort(
      [b, c, a],
      GuildQuestSortOrder.deadlineAsc,
    );
    expect(sorted.first.id, 'b');
    expect(sorted.skip(1).map((t) => t.id).toList(), ['a', 'c']);
  });
}
