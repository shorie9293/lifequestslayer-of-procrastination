// 寄合所クエスト検索画面 — 検索条件の永続化配線の試練。
//
// フェイクの GuildQuestQueryPreferencesStore を注入して、
// 復元・保存のタイミングだけを検証する（保存先の実装は data 側の試練が担う）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/guild_quest_query_preferences.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';

/// 即座に保存済み条件を返し、save を記録するフェイク。
class _RecordingStore implements GuildQuestQueryPreferencesStore {
  _RecordingStore({this.initial});

  final GuildQuestQuery? initial;
  final List<GuildQuestQuery> saved = <GuildQuestQuery>[];
  int loadCalls = 0;

  @override
  Future<GuildQuestQuery?> load() async {
    loadCalls++;
    return initial;
  }

  @override
  Future<void> save(GuildQuestQuery query) async {
    saved.add(query);
  }
}

/// load が外部から完了させられるフェイク（復元タイミングの競合検証用）。
class _DeferredStore implements GuildQuestQueryPreferencesStore {
  final Completer<GuildQuestQuery?> completer = Completer<GuildQuestQuery?>();
  final List<GuildQuestQuery> saved = <GuildQuestQuery>[];

  @override
  Future<GuildQuestQuery?> load() => completer.future;

  @override
  Future<void> save(GuildQuestQuery query) async {
    saved.add(query);
  }
}

final DateTime _now = DateTime(2026, 9, 22, 12, 0, 0);

Task _task(String id, String title, {QuestRank rank = QuestRank.B}) {
  return Task(id: id, title: title, rank: rank);
}

/// deadlineAsc では id 順（a, b）、rankDesc では S が先頭になる2件。
List<Task> _tasks() => [
      _task('a', 'ゴブリン討伐'),
      _task('b', 'ドラゴン討伐', rank: QuestRank.S),
    ];

Future<void> _pump(
  WidgetTester tester, {
  GuildQuestQueryPreferencesStore? store,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: GuildQuestSearchScreen(
        tasksOverride: _tasks(),
        now: _now,
        queryPreferences: store,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _firstCardTitle(WidgetTester tester) {
  return tester
      .widget<Text>(
        find
            .descendant(
              of: find.byKey(AppKeys.guildQuestResultList),
              matching: find.byType(Text),
            )
            .first,
      )
      .data!;
}

void main() {
  testWidgets('保存済みの並び順が開いた直後に反映される', (tester) async {
    final store = _RecordingStore(
      initial: const GuildQuestQuery(sortOrder: GuildQuestSortOrder.rankDesc),
    );
    await _pump(tester, store: store);

    expect(store.loadCalls, 1);
    // 並び替えメニューの表示が保存値になっている
    expect(find.text('難易度が高い順'), findsOneWidget);
    // 実際の並びも S ランクが先頭
    expect(_firstCardTitle(tester), '[S] ドラゴン討伐');
  });

  testWidgets('保存済みの検索語が TextField と一覧に反映される', (tester) async {
    final store = _RecordingStore(
      initial: const GuildQuestQuery(text: 'ドラゴン'),
    );
    await _pump(tester, store: store);

    final field =
        tester.widget<TextField>(find.byKey(AppKeys.guildQuestSearchField));
    expect(field.controller?.text, 'ドラゴン');
    expect(find.text('1件'), findsOneWidget);
    expect(find.text('[S] ドラゴン討伐'), findsOneWidget);
  });

  testWidgets('並び順を変えると即座に save される', (tester) async {
    final store = _RecordingStore();
    await _pump(tester, store: store);
    expect(store.saved, isEmpty);

    await tester.tap(find.byKey(AppKeys.guildQuestSortMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('難易度が高い順').last);
    await tester.pumpAndSettle();

    expect(store.saved, hasLength(1));
    expect(store.saved.single.sortOrder, GuildQuestSortOrder.rankDesc);
  });

  testWidgets('絞り込みを変えると即座に save される', (tester) async {
    final store = _RecordingStore();
    await _pump(tester, store: store);

    await tester.tap(find.byKey(AppKeys.guildQuestStatusChip('overdue')));
    await tester.pump();

    expect(store.saved, hasLength(1));
    expect(store.saved.single.statuses, {GuildQuestStatusFilter.overdue});
  });

  testWidgets('検索語は入力ごとには保存されず、確定後に保存される', (tester) async {
    final store = _RecordingStore();
    await _pump(tester, store: store);

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ドラ');
    await tester.pump();
    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ドラゴン');
    await tester.pump();
    expect(store.saved, isEmpty, reason: '1文字ごとに書いてはならない');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(store.saved, hasLength(1));
    expect(store.saved.single.text, 'ドラゴン');
  });

  testWidgets('検索語は画面を閉じる（dispose）ときにも保存される', (tester) async {
    final store = _RecordingStore();
    await _pump(tester, store: store);

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ゴブリン');
    await tester.pump();
    expect(store.saved, isEmpty);

    // 画面破棄
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(store.saved, isNotEmpty);
    expect(store.saved.last.text, 'ゴブリン');
    expect(tester.takeException(), isNull);
  });

  testWidgets('store 未注入なら保存されず、既存の操作は例外なく動く（後方互換）', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), '討伐');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.guildQuestRankChip('S')));
    await tester.pump();
    expect(find.text('1件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildQuestSearchReset));
    await tester.pump();
    expect(find.text('2件'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('復元より先に打った検索語は上書きされない', (tester) async {
    final store = _DeferredStore();
    await _pump(tester, store: store);

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ゴブリン');
    await tester.pump();

    // 遅れて保存値が届く
    store.completer.complete(const GuildQuestQuery(text: 'ドラゴン'));
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byKey(AppKeys.guildQuestSearchField));
    expect(field.controller?.text, 'ゴブリン');
    expect(find.text('1件'), findsOneWidget);
    expect(find.text('[B] ゴブリン討伐'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('復元が null を返しても既定のまま（並び順は期限順）', (tester) async {
    final store = _RecordingStore();
    await _pump(tester, store: store);

    expect(find.text('期限が近い順'), findsOneWidget);
    expect(_firstCardTitle(tester), '[B] ゴブリン討伐');
  });
}
