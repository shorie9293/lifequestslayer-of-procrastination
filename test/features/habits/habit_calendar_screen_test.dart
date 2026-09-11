import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/habits/presentation/screens/habit_calendar_screen.dart';
import 'package:rpg_todo/features/habits/presentation/widgets/habit_month_grid.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

// ━━━ Hive非依存の試練用モック ━━━

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => Player();
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _MockTaskRepository implements ITaskRepository {
  final List<Task> tasks;
  _MockTaskRepository([this.tasks = const []]);
  @override
  Future<List<Task>> loadTasks() async => tasks;
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

/// 実Hiveを使わない振り返りリポジトリ（widget境界の検証用）。
class _FakeReflectionRepository extends ReflectionRepository {
  final List<Reflection> reflections;
  _FakeReflectionRepository(this.reflections);
  @override
  Future<List<Reflection>> getAll() async => reflections;
}

Reflection _refl(DateTime date) => Reflection(
      id: 'r_${date.millisecondsSinceEpoch}',
      taskId: 't1',
      date: date,
      content: 'content',
      selfDifficulty: 3,
      aiDifficulty: QuestRank.A,
      sentiment: 'kaishin',
    );

void main() {
  // 基準日: 2026-09-15（火）
  final now = DateTime(2026, 9, 15, 12, 0);

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// ListView の遅延描画で下方のカードが未構築にならないよう、
  /// 縦長の試練用ビューポートを設定する。
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('HabitCalendarView', () {
    testWidgets('空データでもサマリカードを表示する', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(
        HabitCalendarView(activityDates: const [], now: now),
      ));
      expect(find.byKey(const Key('habit_calendar_summary')), findsOneWidget);
      expect(find.textContaining('現在の連続勤行'), findsOneWidget);
      expect(find.byKey(const Key('habit_month_grid')), findsOneWidget);
      expect(
        find.text('今月はまだ勤行の記録がありません。今日の一歩から始めよう。'),
        findsOneWidget,
      );
    });

    testWidgets('活動日とストリークを集計表示する', (tester) async {
      await tester.pumpWidget(host(HabitCalendarView(
        activityDates: [
          DateTime(2026, 9, 13),
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 15),
        ],
        now: now,
      )));
      expect(find.text('🔥 現在の連続勤行 3日'), findsOneWidget);
      expect(find.text('3日'), findsWidgets); // 最長連続
      expect(find.byKey(const Key('habit_day_2026-09-15')), findsOneWidget);
      // 経過15日中の活動3日 → 20%
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('月送りでヘッダと対象月が切り替わる', (tester) async {
      await tester.pumpWidget(host(HabitCalendarView(
        activityDates: [DateTime(2026, 8, 1)],
        now: now,
      )));
      expect(find.text('2026年9月'), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit_prev_month')));
      await tester.pumpAndSettle();
      expect(find.text('2026年8月'), findsOneWidget);
      expect(find.byKey(const Key('habit_day_2026-08-01')), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit_next_month')));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月'), findsOneWidget);
    });

    testWidgets('達成率が高い月は称賛メッセージを出す', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(host(HabitCalendarView(
        activityDates: [
          for (var d = 1; d <= 15; d++) DateTime(2026, 9, d),
        ],
        now: now,
      )));
      expect(find.text('見事な継続なり。この調子で連続記録を伸ばそう。'), findsOneWidget);
    });

    testWidgets('週7列の曜日ラベルを持つ', (tester) async {
      await tester.pumpWidget(host(
        HabitCalendarView(activityDates: const [], now: now),
      ));
      for (final label in HabitMonthGrid.weekdayLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('HabitCalendarScreen', () {
    testWidgets('振り返りとクエスト履歴からカレンダーを描画する', (tester) async {
      final repo = _FakeReflectionRepository([
        _refl(DateTime(2026, 9, 14)),
        _refl(DateTime(2026, 9, 15)),
      ]);
      final taskVM = TaskViewModel(
        _MockTaskRepository([
          Task(id: 't1', title: 'quest', lastCompletedAt: DateTime(2026, 9, 15)),
        ]),
        PlayerViewModel(_MockPlayerRepository()),
      );

      // Provider は MaterialApp の外側に置く（push route から解決可能にする）。
      await tester.pumpWidget(
        ChangeNotifierProvider<TaskViewModel>.value(
          value: taskVM,
          child: MaterialApp(
            home: HabitCalendarScreen(repository: repo, now: now),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_habit_calendar')), findsOneWidget);
      expect(find.text('勤行の習慣カレンダー'), findsOneWidget);
      expect(find.byKey(const Key('habit_calendar_view')), findsOneWidget);
      // 9/13(振り返り無し)→…9/14,9/15 活動 → 現在ストリーク2日
      expect(find.text('🔥 現在の連続勤行 2日'), findsOneWidget);
    });
  });
}
