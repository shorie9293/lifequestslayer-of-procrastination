import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query_service.dart';

Task task({
  required String id,
  String title = 'クエスト',
  TaskStatus status = TaskStatus.inGuild,
  bool isCompleted = false,
  QuestRank rank = QuestRank.B,
  RepeatInterval repeatInterval = RepeatInterval.none,
  DateTime? deadline,
  int? repeatAfterDays,
  int? targetTimeMinutes,
  List<String> tags = const [],
}) {
  return Task(
    id: id,
    title: title,
    status: status,
    isCompleted: isCompleted,
    rank: rank,
    repeatInterval: repeatInterval,
    deadline: deadline,
    repeatAfterDays: repeatAfterDays,
    targetTimeMinutes: targetTimeMinutes,
    tags: tags,
  );
}

void main() {
  group('GuildQuestQueryService.normalize', () {
    test('前後空白を除去する', () {
      expect(GuildQuestQueryService.normalize('  abc  '), 'abc');
    });

    test('全角英数字を半角へ変換する', () {
      expect(GuildQuestQueryService.normalize('ＡＢｃ１２３'), 'abc123');
    });

    test('全角スペースを半角スペースへ変換する', () {
      expect(GuildQuestQueryService.normalize('a　b'), 'a b');
    });

    test('小文字化する', () {
      expect(GuildQuestQueryService.normalize('AbC'), 'abc');
    });

    test('連続空白を1つに圧縮する', () {
      expect(GuildQuestQueryService.normalize('a   \t b'), 'a b');
    });

    test('全角変換と空白圧縮の合成', () {
      expect(GuildQuestQueryService.normalize('　Ａ　　Ｂ　'), 'a b');
    });
  });

  group('GuildQuestQueryService.matchesText', () {
    test('空クエリは true', () {
      expect(GuildQuestQueryService.matchesText(task(id: '1'), ''), isTrue);
      expect(GuildQuestQueryService.matchesText(task(id: '1'), '　 '), isTrue);
    });

    test('タイトル部分一致（大文字小文字・全角を正規化）', () {
      final t = task(id: '1', title: 'SlimeＤungeon');
      expect(GuildQuestQueryService.matchesText(t, 'slime'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'ＤＵＮＧＥＯＮ'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'geo'), isTrue);
    });

    test('タグ一致', () {
      final t = task(id: '1', title: '掃除', tags: ['家事', 'Ｒｏｏｍ']);
      expect(GuildQuestQueryService.matchesText(t, '家事'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'room'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'room2'), isFalse);
    });

    test('不一致は false', () {
      expect(
        GuildQuestQueryService.matchesText(task(id: '1', title: '掃除'), '竜'),
        isFalse,
      );
    });

    test('複数語クエリは連続した1文として扱う（圧縮後含まれないなら false）', () {
      final t = task(id: '1', title: '掃除 洗濯');
      expect(GuildQuestQueryService.matchesText(t, '掃除 洗濯'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, '掃除  洗濯'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, '洗濯 掃除'), isFalse);
    });
  });

  group('GuildQuestQueryService.matchesStatus', () {
    final now = DateTime(2026, 9, 22, 12);

    test('active: TaskStatus.active かつ未完了のみ', () {
      final t = task(id: '1', status: TaskStatus.active, isCompleted: false);
      expect(
        GuildQuestQueryService.matchesStatus(
            t, {GuildQuestStatusFilter.active}, now),
        isTrue,
      );
    });

    test('active: inGuild は false / isCompleted は false', () {
      expect(
        GuildQuestQueryService.matchesStatus(task(id: '1', status: TaskStatus.inGuild),
            {GuildQuestStatusFilter.active}, now),
        isFalse,
      );
      expect(
        GuildQuestQueryService.matchesStatus(
            task(id: '1', status: TaskStatus.active, isCompleted: true),
            {GuildQuestStatusFilter.active},
            now),
        isFalse,
      );
    });

    test('overdue: deadline が now より前のみ（deadline == now は超過ではない）', () {
      final before =
          task(id: '1', deadline: DateTime(2026, 9, 22, 11, 59, 59));
      final at = task(id: '2', deadline: DateTime(2026, 9, 22, 12));
      final after = task(id: '3', deadline: DateTime(2026, 9, 22, 12, 0, 1));
      final none = task(id: '4');
      const s = {GuildQuestStatusFilter.overdue};
      expect(GuildQuestQueryService.matchesStatus(before, s, now), isTrue);
      expect(GuildQuestQueryService.matchesStatus(at, s, now), isFalse);
      expect(GuildQuestQueryService.matchesStatus(after, s, now), isFalse);
      expect(GuildQuestQueryService.matchesStatus(none, s, now), isFalse);
    });

    test('recurring: repeatInterval が none 以外か repeatAfterDays あり', () {
      const s = {GuildQuestStatusFilter.recurring};
      expect(
        GuildQuestQueryService.matchesStatus(
            task(id: '1', repeatInterval: RepeatInterval.daily), s, now),
        isTrue,
      );
      expect(
        GuildQuestQueryService.matchesStatus(
            task(id: '2', repeatInterval: RepeatInterval.weekly), s, now),
        isTrue,
      );
      expect(
        GuildQuestQueryService.matchesStatus(
            task(id: '3', repeatAfterDays: 3), s, now),
        isTrue,
      );
      expect(
        GuildQuestQueryService.matchesStatus(task(id: '4'), s, now),
        isFalse,
      );
    });

    test('statuses 空 = 全通過', () {
      expect(
        GuildQuestQueryService.matchesStatus(task(id: '1'), {}, now),
        isTrue,
      );
    });

    test('複数指定は OR', () {
      final t = task(id: '1', repeatInterval: RepeatInterval.daily);
      expect(
        GuildQuestQueryService.matchesStatus(
            t, {GuildQuestStatusFilter.overdue, GuildQuestStatusFilter.recurring}, now),
        isTrue,
      );
    });
  });

  group('GuildQuestQueryService.matchesRank', () {
    test('空は true', () {
      expect(GuildQuestQueryService.matchesRank(task(id: '1'), {}), isTrue);
    });

    test('単一指定', () {
      const s = {QuestRank.S};
      expect(GuildQuestQueryService.matchesRank(task(id: '1', rank: QuestRank.S), s), isTrue);
      expect(GuildQuestQueryService.matchesRank(task(id: '2', rank: QuestRank.B), s), isFalse);
    });

    test('複数指定', () {
      const s = {QuestRank.S, QuestRank.A};
      expect(GuildQuestQueryService.matchesRank(task(id: '1', rank: QuestRank.A), s), isTrue);
      expect(GuildQuestQueryService.matchesRank(task(id: '2', rank: QuestRank.B), s), isFalse);
    });
  });

  group('GuildQuestQueryService.sort', () {
    test('deadlineAsc: 非null昇順で先に、nullは末尾、同値はid昇順', () {
      final a = task(id: 'b2', deadline: DateTime(2026, 1, 1));
      final b = task(id: 'a1', deadline: DateTime(2026, 1, 1));
      final c = task(id: 'c3', deadline: DateTime(2026, 5, 1));
      final d = task(id: 'd4');
      final input = [d, c, b, a];
      final result = GuildQuestQueryService.sort(
          input, GuildQuestSortOrder.deadlineAsc);
      expect(result.map((t) => t.id).toList(), ['a1', 'b2', 'c3', 'd4']);
      expect(input.map((t) => t.id).toList(), ['d4', 'c3', 'a1', 'b2']);
    });

    test('rankDesc: S→A→B の順（index 昇順）', () {
      final s = task(id: '1', rank: QuestRank.S);
      final a = task(id: '2', rank: QuestRank.A);
      final b = task(id: '3', rank: QuestRank.B);
      final result = GuildQuestQueryService.sort(
          [b, s, a], GuildQuestSortOrder.rankDesc);
      expect(result.map((t) => t.rank).toList(),
          [QuestRank.S, QuestRank.A, QuestRank.B]);
    });

    test('rankDesc: 同rankは normalize(title) 昇順→id昇順', () {
      final x = task(id: '2', rank: QuestRank.A, title: 'ｂ');
      final y = task(id: '1', rank: QuestRank.A, title: 'ａ');
      final result = GuildQuestQueryService.sort(
          [x, y], GuildQuestSortOrder.rankDesc);
      expect(result.map((t) => t.id).toList(), ['1', '2']);
    });

    test('timeDesc: 非null降順で先に、nullは末尾、同値はid昇順', () {
      final a = task(id: 'a1', targetTimeMinutes: 30);
      final b = task(id: 'b2', targetTimeMinutes: 60);
      final c = task(id: 'c3', targetTimeMinutes: 60);
      final d = task(id: 'd4');
      final result = GuildQuestQueryService.sort(
          [d, a, c, b], GuildQuestSortOrder.timeDesc);
      expect(result.map((t) => t.id).toList(), ['b2', 'c3', 'a1', 'd4']);
    });

    test('titleAsc: normalize(title) 昇順、同値はid昇順', () {
      final a = task(id: '2', title: 'ｂ');
      final b = task(id: '1', title: 'ａ');
      final c = task(id: '3', title: 'Ａ');
      final result =
          GuildQuestQueryService.sort([a, b, c], GuildQuestSortOrder.titleAsc);
      expect(result.map((t) => t.id).toList(), ['1', '3', '2']);
    });
  });

  group('GuildQuestQueryService.apply', () {
    final now = DateTime(2026, 9, 22, 12);

    test('絞り込みの合成（text + status + rank）', () {
      final t1 = task(id: '1', title: '掃除',
          status: TaskStatus.active, rank: QuestRank.A);
      final t2 = task(id: '2', title: '掃除', rank: QuestRank.A);
      final t3 = task(id: '3', title: '洗濯',
          status: TaskStatus.active, rank: QuestRank.A);
      final t4 = task(id: '4', title: '掃除',
          status: TaskStatus.active, rank: QuestRank.S);
      final query = GuildQuestQuery(
        text: '掃除',
        statuses: const {GuildQuestStatusFilter.active},
        ranks: const {QuestRank.A},
      );
      final result = GuildQuestQueryService.apply([t1, t2, t3, t4], query,
          now: now);
      expect(result.map((t) => t.id).toList(), ['1']);
    });

    test('並び替えを適用する', () {
      final t1 = task(id: '1', targetTimeMinutes: 30);
      final t2 = task(id: '2', targetTimeMinutes: 60);
      final result = GuildQuestQueryService.apply([t1, t2],
          const GuildQuestQuery(sortOrder: GuildQuestSortOrder.timeDesc),
          now: now);
      expect(result.map((t) => t.id).toList(), ['2', '1']);
    });

    test('入力リストを破壊しない', () {
      final t1 = task(id: '1', deadline: DateTime(2026, 3, 1));
      final t2 = task(id: '2', deadline: DateTime(2026, 1, 1));
      final input = [t1, t2];
      GuildQuestQueryService.apply(input, const GuildQuestQuery(), now: now);
      expect(input.map((t) => t.id).toList(), ['1', '2']);
    });

    test('deadline null 混在でも例外を投げない', () {
      final t1 = task(id: '1');
      final t2 = task(id: '2', deadline: DateTime(2026, 1, 1));
      expect(
        () => GuildQuestQueryService.apply([t1, t2],
            const GuildQuestQuery(), now: now),
        returnsNormally,
      );
    });

    test('該当0件で空リスト', () {
      final result = GuildQuestQueryService.apply(
          [task(id: '1')], const GuildQuestQuery(text: '存在しない'), now: now);
      expect(result, isEmpty);
    });
  });

  group('GuildQuestQuery', () {
    test('const コンストラクタが使える', () {
      const q = GuildQuestQuery();
      expect(q.text, '');
      expect(q.statuses, isEmpty);
      expect(q.ranks, isEmpty);
      expect(q.sortOrder, GuildQuestSortOrder.deadlineAsc);
    });

    test('isDefault', () {
      const q = GuildQuestQuery();
      expect(q.isDefault, isTrue);
      expect(q.copyWith(text: 'x').isDefault, isFalse);
      expect(
        const GuildQuestQuery(
                statuses: {GuildQuestStatusFilter.active}).isDefault,
        isFalse,
      );
      expect(const GuildQuestQuery(ranks: {QuestRank.S}).isDefault, isFalse);
      expect(
        const GuildQuestQuery(
                sortOrder: GuildQuestSortOrder.titleAsc).isDefault,
        isFalse,
      );
    });

    test('activeFilterCount', () {
      const q = GuildQuestQuery();
      expect(q.activeFilterCount, 0);
      expect(q.copyWith(text: '掃除').activeFilterCount, 1);
      expect(
        q.copyWith(
                text: '掃除',
                statuses: {GuildQuestStatusFilter.active,
                    GuildQuestStatusFilter.overdue},
                ranks: {QuestRank.S},
                sortOrder: GuildQuestSortOrder.titleAsc).activeFilterCount,
        5,
      );
    });

    test('copyWith: null は据え置き', () {
      const base = GuildQuestQuery(
        text: '掃除',
        statuses: {GuildQuestStatusFilter.active},
        ranks: {QuestRank.S},
        sortOrder: GuildQuestSortOrder.titleAsc,
      );
      final copied = base.copyWith();
      expect(copied.text, '掃除');
      expect(copied.statuses, {GuildQuestStatusFilter.active});
      expect(copied.ranks, {QuestRank.S});
      expect(copied.sortOrder, GuildQuestSortOrder.titleAsc);
      expect(copied.copyWith(text: '洗濯').text, '洗濯');
      expect(copied.copyWith(sortOrder: GuildQuestSortOrder.deadlineAsc)
          .sortOrder, GuildQuestSortOrder.deadlineAsc);
    });

    test('== と hashCode', () {
      const a = GuildQuestQuery(text: 'x', statuses: {GuildQuestStatusFilter.active}, ranks: {QuestRank.S});
      const b = GuildQuestQuery(text: 'x', statuses: {GuildQuestStatusFilter.active}, ranks: {QuestRank.S});
      const c = GuildQuestQuery(text: 'y', statuses: {GuildQuestStatusFilter.active}, ranks: {QuestRank.S});
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      // Set順序に依存しない比較
      const d = GuildQuestQuery(
          statuses: {GuildQuestStatusFilter.active,
              GuildQuestStatusFilter.overdue});
      const e = GuildQuestQuery(
          statuses: {GuildQuestStatusFilter.overdue,
              GuildQuestStatusFilter.active});
      expect(d, e);
    });
  });
}