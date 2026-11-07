// 親探針: **本番と同じ SharedPreferences ストア**を通した往復を撃つ。
//
// 子の試練はフェイクの store を注入して「復元タイミング」と「保存タイミング」を
// 個別に検証するが、本番キー・本番ストア実装・画面配線の合成は撃たない。
// ここでは 画面A で条件を変えて破棄 → 画面B を開き直して復元されることを実測する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/guild_quest_query_preferences.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';

Task _task(String id, String title, {QuestRank rank = QuestRank.B}) =>
    Task(id: id, title: title, rank: rank);

List<Task> _tasks() => [
      _task('a', 'ゴブリン討伐'),
      _task('b', 'ドラゴン討伐', rank: QuestRank.S),
    ];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    GuildQuestQueryPreferencesStore store,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GuildQuestSearchScreen(
          tasksOverride: _tasks(),
          now: DateTime(2026, 11, 7, 12),
          queryPreferences: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('本番ストアで画面Aの条件が画面Bへ復元される（往復）', (tester) async {
    const store = SharedPreferencesGuildQuestQueryPreferencesStore();

    // 画面A: 並び順と検索語を変える
    await pumpScreen(tester, store);
    await tester.tap(find.byKey(AppKeys.guildQuestSortMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('難易度が高い順').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ドラゴン');
    await tester.pump();

    // 画面破棄（dispose で検索語を保存する）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // 本番キーに実値が入っていることを一次情報で確認する
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      SharedPreferencesGuildQuestQueryPreferencesStore.storageKey,
    );
    expect(raw, isNotNull);
    expect(raw, contains('rankDesc'));

    // 画面B: 開き直すと復元されている
    await pumpScreen(tester, store);
    expect(find.text('難易度が高い順'), findsOneWidget);
    final field =
        tester.widget<TextField>(find.byKey(AppKeys.guildQuestSearchField));
    expect(field.controller?.text, 'ドラゴン');
    expect(find.text('1件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存値が壊れていても既定条件で開き、例外を漏らさない', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesGuildQuestQueryPreferencesStore.storageKey: '{壊れた',
    });
    const store = SharedPreferencesGuildQuestQueryPreferencesStore();

    await pumpScreen(tester, store);

    expect(find.text('期限が近い順'), findsOneWidget);
    expect(find.text('2件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
