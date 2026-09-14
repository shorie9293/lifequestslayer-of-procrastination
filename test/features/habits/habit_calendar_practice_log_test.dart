import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/habits/data/practice_log_repository.dart';
import 'package:rpg_todo/features/habits/presentation/screens/habit_calendar_screen.dart';
import 'package:rpg_todo/features/habits/presentation/widgets/habit_month_grid.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// 実 Hive を使わない試練用モック群。
///
/// 注: Hive 未初期化で `Hive.openBox` を呼ぶと hive 内部の Completer が
/// 未処理エラーを zone へ流し、widget テストが落ちる（hive 2.2.3 の仕様）。
/// ゆえに画面へは必ずフェイクを注入する。
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

class _FakeReflectionRepository extends ReflectionRepository {
  final List<Reflection> reflections;
  _FakeReflectionRepository(this.reflections);
  @override
  Future<List<Reflection>> getAll() async => reflections;
}

class _FakePracticeLogRepository extends PracticeLogRepository {
  final List<PracticeLog> logs;
  _FakePracticeLogRepository(this.logs);
  @override
  Future<List<PracticeLog>> getAll() async => logs;
}

PracticeLog _log(DateTime date, int count) =>
    PracticeLog(date: date, count: count);

void main() {
  // 基準日: 2026-09-15（火）12:00
  final now = DateTime(2026, 9, 15, 12, 0);

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required PracticeLogRepository logs,
    List<Task> tasks = const [],
    List<Reflection> reflections = const [],
  }) async {
    final taskVM = TaskViewModel(
      _MockTaskRepository(tasks),
      PlayerViewModel(_MockPlayerRepository()),
    );
    await taskVM.load();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskViewModel>.value(
        value: taskVM,
        child: MaterialApp(
          home: HabitCalendarScreen(
            repository: _FakeReflectionRepository(reflections),
            practiceLogRepository: logs,
            now: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? cellColor(WidgetTester tester, String key) {
    final container = tester.widget<Container>(find.byKey(Key(key)));
    return (container.decoration! as BoxDecoration).color;
  }

  group('HabitCalendarScreen 日別履歴ログ統合（#50）', () {
    testWidgets('日別ログのみでもカレンダーとストリークに反映される', (tester) async {
      useTallViewport(tester);
      await pumpScreen(tester,
          logs: _FakePracticeLogRepository([
            _log(DateTime(2026, 9, 13), 1),
            _log(DateTime(2026, 9, 14), 1),
            _log(DateTime(2026, 9, 15), 1),
          ]));

      expect(find.byKey(const Key('screen_habit_calendar')), findsOneWidget);
      expect(find.text('🔥 現在の連続勤行 3日'), findsOneWidget);
      expect(cellColor(tester, 'habit_day_2026-09-13'),
          HabitMonthGrid.activeColor);
      expect(cellColor(tester, 'habit_day_2026-09-12'),
          isNot(HabitMonthGrid.activeColor));
    });

    testWidgets('ログが無い日は旧来ソース（クエスト履歴）で補完される', (tester) async {
      await pumpScreen(
        tester,
        logs: _FakePracticeLogRepository(const []),
        tasks: [
          Task(id: 't1', title: 'quest', lastCompletedAt: DateTime(2026, 9, 9)),
        ],
      );

      expect(cellColor(tester, 'habit_day_2026-09-09'),
          HabitMonthGrid.activeColor);
    });

    testWidgets('ログのある日は旧来ソースと二重計上しない', (tester) async {
      useTallViewport(tester);
      await pumpScreen(
        tester,
        logs: _FakePracticeLogRepository([_log(DateTime(2026, 9, 9), 3)]),
        tasks: [
          Task(id: 't1', title: 'quest', lastCompletedAt: DateTime(2026, 9, 9)),
        ],
      );

      // ログ3件のみ（旧来の lastCompletedAt を加算して4件にはしない）
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>();
      expect(labels, contains('9月9日 勤行3件'));
    });
  });
}
