import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query_service.dart';

Task _task(
  String id, {
  String title = 'q',
  QuestRank rank = QuestRank.B,
  List<String> tags = const [],
  DateTime? deadline,
}) =>
    Task(
      id: id,
      title: title,
      rank: rank,
      tags: List<String>.of(tags),
      deadline: deadline,
    );

void main() {
  group('GuildQuestQuery.tags', () {
    test('既定値は空集合で isDefault は true', () {
      const q = GuildQuestQuery();
      expect(q.tags, isEmpty);
      expect(q.isDefault, isTrue);
    });

    test('tags があると isDefault は false', () {
      const q = GuildQuestQuery(tags: {'a'});
      expect(q.isDefault, isFalse);
    });

    test('activeFilterCount に tags の件数が加算される', () {
      const q = GuildQuestQuery(tags: {'a', 'b'});
      expect(q.activeFilterCount, 2);
    });

    test('copyWith で tags を差し替えられる', () {
      const q = GuildQuestQuery();
      final next = q.copyWith(tags: {'x'});
      expect(next.tags, {'x'});
      expect(next.text, '');
    });

    test('等価性に tags が効く（順序非依存）', () {
      expect(const GuildQuestQuery(tags: {'a', 'b'}),
          const GuildQuestQuery(tags: {'b', 'a'}));
      expect(const GuildQuestQuery(tags: {'a'}).hashCode,
          const GuildQuestQuery(tags: {'a'}).hashCode);
      expect(const GuildQuestQuery(tags: {'a'}) == const GuildQuestQuery(),
          isFalse);
    });
  });

  group('GuildQuestQueryService.apply with tags', () {
    test('タグで絞り込む', () {
      final tasks = [
        _task('1', tags: ['work']),
        _task('2', tags: ['home']),
      ];
      final result =
          GuildQuestQueryService.apply(tasks, const GuildQuestQuery(tags: {'work'}));
      expect(result.map((e) => e.id).toList(), ['1']);
    });

    test('rank 絞込とタグ絞込の積集合になる', () {
      final tasks = [
        _task('1', rank: QuestRank.S, tags: ['work']),
        _task('2', rank: QuestRank.S, tags: ['home']),
        _task('3', rank: QuestRank.B, tags: ['work']),
      ];
      final result = GuildQuestQueryService.apply(
        tasks,
        const GuildQuestQuery(ranks: {QuestRank.S}, tags: {'work'}),
      );
      expect(result.map((e) => e.id).toList(), ['1']);
    });

    test('テキスト・状態・タグが合成される', () {
      final now = DateTime.utc(2026, 1, 2, 12).toLocal();
      final tasks = [
        _task('1',
            title: '買い物',
            tags: ['work'],
            deadline: DateTime.utc(2026, 1, 1, 12).toLocal()),
        _task('2',
            title: '買い物',
            tags: ['home'],
            deadline: DateTime.utc(2026, 1, 1, 12).toLocal()),
        _task('3',
            title: '掃除',
            tags: ['work'],
            deadline: DateTime.utc(2026, 1, 1, 12).toLocal()),
      ];
      final result = GuildQuestQueryService.apply(
        tasks,
        const GuildQuestQuery(
          text: '買い物',
          statuses: {GuildQuestStatusFilter.overdue},
          tags: {'work'},
        ),
        now: now,
      );
      expect(result.map((e) => e.id).toList(), ['1']);
    });

    test('tags が空なら従来と同一結果', () {
      final now = DateTime.utc(2026, 1, 1).toLocal();
      final tasks = [
        _task('1', title: 'b', tags: ['work']),
        _task('2', title: 'a', tags: ['home']),
      ];
      final withEmptyTags = GuildQuestQueryService.apply(
        tasks,
        const GuildQuestQuery(sortOrder: GuildQuestSortOrder.titleAsc),
        now: now,
      );
      final legacy = GuildQuestQueryService.apply(
        tasks,
        const GuildQuestQuery(sortOrder: GuildQuestSortOrder.titleAsc),
        now: now,
      );
      expect(withEmptyTags.map((e) => e.id).toList(),
          legacy.map((e) => e.id).toList());
      expect(withEmptyTags.length, 2);
    });

    test('タグ比較は大文字小文字無視', () {
      final tasks = [_task('1', tags: ['Work'])];
      final result = GuildQuestQueryService.apply(
        tasks,
        const GuildQuestQuery(tags: {'work'}),
      );
      expect(result.map((e) => e.id).toList(), ['1']);
    });
  });
}
