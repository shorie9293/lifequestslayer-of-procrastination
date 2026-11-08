// 検索語の履歴チップ（表示部品）と検索画面への配線の試練。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/search/search_history.dart';
import 'package:rpg_todo/core/search/search_history_chips.dart';
import 'package:rpg_todo/core/search/search_history_store.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';

/// メモリ上の履歴保存先。load / save を記録する。
class _FakeHistoryStore implements SearchHistoryStore {
  _FakeHistoryStore([SearchHistory? initial])
      : history = initial ?? const SearchHistory.empty();

  SearchHistory history;
  int loadCalls = 0;
  final List<SearchHistory> saved = <SearchHistory>[];

  @override
  Future<SearchHistory> load() async {
    loadCalls++;
    return history;
  }

  @override
  Future<void> save(SearchHistory h) async {
    history = h;
    saved.add(h);
  }
}

final DateTime _now = DateTime(2026, 9, 22, 12, 0, 0);

List<Task> _tasks() => [
      Task(id: 'a', title: 'ドラゴン討伐', rank: QuestRank.S),
      Task(id: 'b', title: 'ゴブリン討伐'),
      Task(id: 'c', title: '薬草採取', tags: ['採集']),
    ];

Future<void> _pumpChips(
  WidgetTester tester, {
  List<String> entries = const [],
  ValueChanged<String>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SearchHistoryChips(
          entries: entries,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SearchHistoryStore store,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: GuildQuestSearchScreen(
        tasksOverride: _tasks(),
        now: _now,
        searchHistoryStore: store,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('履歴が空ならチップを描かない', (tester) async {
    await _pumpChips(tester);

    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('履歴を新しい順にチップで表示する', (tester) async {
    await _pumpChips(tester, entries: ['採集', '討伐']);

    final chips =
        tester.widgetList<ActionChip>(find.byType(ActionChip)).toList();
    expect(chips, hasLength(2));
    expect((chips[0].label as Text).data, '採集');
    expect((chips[1].label as Text).data, '討伐');
    expect(
        find.byKey(const ValueKey('search history chip 採集')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('search history chip 討伐')), findsOneWidget);
  });

  testWidgets('チップをタップすると語が onSelected へ渡る', (tester) async {
    String? selected;
    await _pumpChips(
      tester,
      entries: ['採集'],
      onSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const ValueKey('search history chip 採集')));
    await tester.pump();

    expect(selected, '採集');
  });

  testWidgets('画面初期化時に保存済みの履歴を読み込んで表示する', (tester) async {
    final store = _FakeHistoryStore(
      const SearchHistory.empty().add('討伐').add('採集'),
    );

    await _pumpScreen(tester, store: store);

    expect(store.loadCalls, 1);
    expect(
      find.byKey(const ValueKey('search history chip 採集')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('search history chip 討伐')),
      findsOneWidget,
    );
  });

  testWidgets('確定（onSubmitted）でのみ履歴へ積まれ、入力中は積まれない', (tester) async {
    final store = _FakeHistoryStore();
    await _pumpScreen(tester, store: store);

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ドラ');
    await tester.pump();
    await tester.enterText(
      find.byKey(AppKeys.guildQuestSearchField),
      'ドラゴン',
    );
    await tester.pump();
    expect(store.saved, isEmpty, reason: '1文字ごとに積んではならない');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(store.saved, hasLength(1));
    expect(store.saved.single.entries, ['ドラゴン']);
    expect(
      find.byKey(const ValueKey('search history chip ドラゴン')),
      findsOneWidget,
    );
  });

  testWidgets('画面離脱時に非空の検索語が履歴へ積まれる', (tester) async {
    final store = _FakeHistoryStore();
    await _pumpScreen(tester, store: store);

    await tester.enterText(
      find.byKey(AppKeys.guildQuestSearchField),
      '  ゴブリン\u3000討伐 ',
    );
    await tester.pump();
    expect(store.saved, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(store.saved, hasLength(1));
    expect(store.saved.single.entries, ['ゴブリン 討伐']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('検索語が空のまま離脱しても履歴は積まれない', (tester) async {
    final store = _FakeHistoryStore();
    await _pumpScreen(tester, store: store);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(store.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('履歴チップのタップで検索欄と結果が更新される', (tester) async {
    final store = _FakeHistoryStore(
      const SearchHistory.empty().add('ドラゴン'),
    );
    await _pumpScreen(tester, store: store);

    expect(find.text('3件'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('search history chip ドラゴン')),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(AppKeys.guildQuestSearchField),
    );
    expect(field.controller?.text, 'ドラゴン');
    expect(find.text('1件'), findsOneWidget);
    expect(find.text('[S] ドラゴン討伐'), findsOneWidget);
    // チップのタップでは履歴を書かない（保存は確定と離脱のみ）
    expect(store.saved, isEmpty);
  });

  testWidgets('store 未注入でも画面は動き、履歴チップは空のまま（後方互換）', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: GuildQuestSearchScreen(
          tasksOverride: _tasks(),
          now: _now,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('3件'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
