// 寄合所クエスト検索条件の永続化 — コーデックと保存先の試練。
//
// 最重要の受け入れ基準: decode は決して例外を投げない（起動時に読むため）。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/guild_quest_query_preferences.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';

const GuildQuestQuery _full = GuildQuestQuery(
  text: 'ドラゴン討伐',
  statuses: {
    GuildQuestStatusFilter.active,
    GuildQuestStatusFilter.overdue,
  },
  ranks: {QuestRank.S, QuestRank.B},
  tags: {'戦闘', '冒険'},
  sortOrder: GuildQuestSortOrder.rankDesc,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuildQuestQueryPreferences.encode/decode', () {
    test('全フィールドが round-trip する', () {
      final decoded = GuildQuestQueryPreferences.decode(
        GuildQuestQueryPreferences.encode(_full),
      );

      expect(decoded.text, 'ドラゴン討伐');
      expect(decoded.statuses, _full.statuses);
      expect(decoded.ranks, _full.ranks);
      expect(decoded.tags, _full.tags);
      expect(decoded.sortOrder, GuildQuestSortOrder.rankDesc);
      expect(decoded, _full);
    });

    test('既定クエリも round-trip する', () {
      const defaultQuery = GuildQuestQuery();
      final decoded = GuildQuestQueryPreferences.decode(
        GuildQuestQueryPreferences.encode(defaultQuery),
      );
      expect(decoded, defaultQuery);
    });

    test('encode は仕様どおりのキーと enum.name を書く', () {
      final map = jsonDecode(GuildQuestQueryPreferences.encode(_full))
          as Map<String, dynamic>;

      expect(
          map.keys.toSet(), {'text', 'statuses', 'ranks', 'tags', 'sortOrder'});
      expect(map['text'], 'ドラゴン討伐');
      expect((map['statuses'] as List).toSet(), {'active', 'overdue'});
      expect((map['ranks'] as List).toSet(), {'S', 'B'});
      expect(map['sortOrder'], 'rankDesc');
    });

    test('null・空文字・空白のみは既定クエリ（例外なし）', () {
      for (final raw in <String?>[null, '', '   ', '\n\t']) {
        expect(GuildQuestQueryPreferences.decode(raw), const GuildQuestQuery());
      }
    });

    test('壊れた JSON は既定クエリ（例外なし）', () {
      for (final raw in <String>[
        '{',
        'not json',
        '{"text": "a",,}',
        '{"text": "a"',
        '\u0000\u0001',
      ]) {
        expect(GuildQuestQueryPreferences.decode(raw), const GuildQuestQuery());
      }
    });

    test('JSON だが Map でない値は既定クエリ（例外なし）', () {
      for (final raw in <String>['[]', '[1,2]', '"string"', '123', 'true']) {
        expect(GuildQuestQueryPreferences.decode(raw), const GuildQuestQuery());
      }
    });

    test('型不一致のフィールドは既定値へ落ちる（例外なし）', () {
      final decoded = GuildQuestQueryPreferences.decode(
        '{"text": 42, "statuses": "active", "ranks": 5, '
        '"tags": {"a": 1}, "sortOrder": false}',
      );
      expect(decoded, const GuildQuestQuery());
    });

    test('未知の enum 名は既定値へ落ち、既知の値は残る', () {
      final decoded = GuildQuestQueryPreferences.decode(
        '{"statuses": ["active", "bogus"], "ranks": ["Z", "S"], '
        '"sortOrder": "nope"}',
      );
      expect(decoded.statuses, {GuildQuestStatusFilter.active});
      expect(decoded.ranks, {QuestRank.S});
      expect(decoded.sortOrder, GuildQuestSortOrder.deadlineAsc);
    });

    test('未知のキーは無視される', () {
      final decoded = GuildQuestQueryPreferences.decode(
        '{"text": "薬草", "futureKey": 1, "nested": {"a": 1}}',
      );
      expect(decoded.text, '薬草');
      expect(decoded, const GuildQuestQuery(text: '薬草'));
    });

    test('tags は trim され、空文字は捨てられる', () {
      final decoded = GuildQuestQueryPreferences.decode(
        '{"tags": [" 戦闘 ", "", "   ", "冒険"]}',
      );
      expect(decoded.tags, {'戦闘', '冒険'});
    });

    test('重複した enum 名・タグは除去される', () {
      final decoded = GuildQuestQueryPreferences.decode(
        '{"statuses": ["active", "active"], "ranks": ["S", "S"], '
        '"tags": ["戦闘", "戦闘", " 戦闘 "]}',
      );
      expect(decoded.statuses, hasLength(1));
      expect(decoded.ranks, hasLength(1));
      expect(decoded.tags, hasLength(1));
      expect(decoded.statuses, {GuildQuestStatusFilter.active});
      expect(decoded.ranks, {QuestRank.S});
      expect(decoded.tags, {'戦闘'});
    });

    test('文字列以外が混じった配列は有効な要素だけ拾う', () {
      final decoded = GuildQuestQueryPreferences.decode(
        '{"statuses": ["active", 1, null], "tags": ["戦闘", 3]}',
      );
      expect(decoded.statuses, {GuildQuestStatusFilter.active});
      expect(decoded.tags, {'戦闘'});
    });
  });

  group('SharedPreferencesGuildQuestQueryPreferencesStore', () {
    const store = SharedPreferencesGuildQuestQueryPreferencesStore();

    test('保存キーは guild_quest_search_query_v1', () {
      expect(SharedPreferencesGuildQuestQueryPreferencesStore.storageKey,
          'guild_quest_search_query_v1');
    });

    test('save → load で round-trip する', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await store.save(_full);
      final loaded = await store.load();

      expect(loaded, _full);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
            SharedPreferencesGuildQuestQueryPreferencesStore.storageKey),
        GuildQuestQueryPreferences.encode(_full),
      );
    });

    test('キー不在なら null（未保存と空クエリを区別する）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await store.load(), isNull);
    });

    test('壊れた値でも null ではなく既定クエリを返す', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesGuildQuestQueryPreferencesStore.storageKey:
            '{broken json',
      });

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded, const GuildQuestQuery());
    });

    test('保存後に上書き保存すると最新値が読める', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await store.save(_full);
      await store.save(const GuildQuestQuery(
          text: '薬草', sortOrder: GuildQuestSortOrder.titleAsc));

      final loaded = await store.load();
      expect(loaded!.text, '薬草');
      expect(loaded.sortOrder, GuildQuestSortOrder.titleAsc);
      expect(loaded.statuses, isEmpty);
    });
  });
}
