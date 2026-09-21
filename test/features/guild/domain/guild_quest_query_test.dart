import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';

void main() {
  group('GuildQuestStatusFilter', () {
    test('ラベルを持つ', () {
      expect(GuildQuestStatusFilter.active.label, '挑戦中');
      expect(GuildQuestStatusFilter.overdue.label, '期日超過');
      expect(GuildQuestStatusFilter.recurring.label, '繰り返し');
    });
  });

  group('GuildQuestSortOrder', () {
    test('ラベルを持つ', () {
      expect(GuildQuestSortOrder.deadlineAsc.label, '期限が近い順');
      expect(GuildQuestSortOrder.rankDesc.label, '難易度が高い順');
      expect(GuildQuestSortOrder.timeDesc.label, '見積もりが長い順');
      expect(GuildQuestSortOrder.titleAsc.label, '名前順');
    });
  });

  group('GuildQuestQuery', () {
    test('const コンストラクタで既定値', () {
      const q = GuildQuestQuery();
      expect(q.text, '');
      expect(q.statuses, isEmpty);
      expect(q.ranks, isEmpty);
      expect(q.sortOrder, GuildQuestSortOrder.deadlineAsc);
      expect(q.isDefault, isTrue);
      expect(q.activeFilterCount, 0);
    });

    test('isDefault は各条件で false になる', () {
      const q = GuildQuestQuery();
      expect(q.copyWith(text: ' 掃除 ').isDefault, isFalse);
      expect(q.copyWith(statuses: {GuildQuestStatusFilter.overdue}).isDefault,
          isFalse);
      expect(q.copyWith(ranks: {QuestRank.B}).isDefault, isFalse);
      expect(
          q.copyWith(sortOrder: GuildQuestSortOrder.rankDesc).isDefault,
          isFalse);
      // 空白のみのテキストは既定扱い
      expect(const GuildQuestQuery(text: '　').isDefault, isTrue);
    });

    test('activeFilterCount の計算', () {
      const q = GuildQuestQuery();
      expect(q.activeFilterCount, 0);
      expect(q.copyWith(text: 'x').activeFilterCount, 1);
      expect(q.copyWith(sortOrder: GuildQuestSortOrder.timeDesc)
          .activeFilterCount, 1);
      expect(
        const GuildQuestQuery(
          text: 'x',
          statuses: {GuildQuestStatusFilter.active,
              GuildQuestStatusFilter.recurring},
          ranks: {QuestRank.A, QuestRank.S},
          sortOrder: GuildQuestSortOrder.titleAsc,
        ).activeFilterCount,
        6,
      );
    });

    test('copyWith は既存値を維持し、指定のみ変更する', () {
      const base = GuildQuestQuery(text: '掃除', ranks: {QuestRank.S});
      final copied = base.copyWith(
          sortOrder: GuildQuestSortOrder.titleAsc,
          statuses: {GuildQuestStatusFilter.active});
      expect(copied.text, '掃除');
      expect(copied.ranks, {QuestRank.S});
      expect(copied.sortOrder, GuildQuestSortOrder.titleAsc);
      expect(copied.statuses, {GuildQuestStatusFilter.active});
    });

    test('== は全フィールド一致（Setは順序非依存）', () {
      const a = GuildQuestQuery(
          text: 't',
          statuses: {GuildQuestStatusFilter.active,
              GuildQuestStatusFilter.overdue},
          ranks: {QuestRank.A},
          sortOrder: GuildQuestSortOrder.timeDesc);
      const b = GuildQuestQuery(
          text: 't',
          statuses: {GuildQuestStatusFilter.overdue,
              GuildQuestStatusFilter.active},
          ranks: {QuestRank.A},
          sortOrder: GuildQuestSortOrder.timeDesc);
      const c = GuildQuestQuery(
          text: 't',
          statuses: {GuildQuestStatusFilter.active},
          ranks: {QuestRank.A},
          sortOrder: GuildQuestSortOrder.timeDesc);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == '42', isFalse);
    });
  });
}