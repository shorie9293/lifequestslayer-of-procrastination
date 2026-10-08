import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/habits/data/practice_log_repository.dart';
import 'package:rpg_todo/features/habits/presentation/screens/habit_calendar_screen.dart';
import 'package:rpg_todo/features/habits/presentation/widgets/practice_heatmap.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/domain/models/reflection.dart';

/// 勤行ヒートマップの widget 試練（ドメイン PracticeHeatmapService は既 GREEN）。
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
  _MockTaskRepository();
  @override
  Future<List<Task>> loadTasks() async => const [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

class _FakeReflectionRepository extends ReflectionRepository {
  @override
  Future<List<Reflection>> getAll() async => const [];
}

class _FakePracticeLogRepository extends PracticeLogRepository {
  final List<PracticeLog> logs;
  _FakePracticeLogRepository(this.logs);
  @override
  Future<List<PracticeLog>> getAll() async => logs;
}

PracticeLog _log(DateTime date, int count, {DateTime? updatedAt}) =>
    PracticeLog(date: date, count: count, updatedAt: updatedAt);

void main() {
  group('PracticeHeatmapView widget 試練', () {
    Future<void> pumpView(WidgetTester tester, List<PracticeLog> logs) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PracticeHeatmapView(logs: logs))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('空ログ→ 空状態キーが出る', (tester) async {
      await pumpView(tester, const []);

      expect(find.byKey(AppKeys.practiceHeatmapEmpty), findsOneWidget);
      expect(find.text('まだ記録がありません'), findsOneWidget);
      // セルは非表示
      expect(find.byKey(const Key('practice_heatmap_cell_1_0')), findsNothing);
    });

    testWidgets('複数ログ→ 28セル・濃淡セル・サマリー・busiestBand', (tester) async {
      // 2026-09-14 は月曜。夜18時→band3、朝9時→band1。
      await pumpView(tester, [
        _log(DateTime(2026, 9, 14), 2, updatedAt: DateTime(2026, 9, 14, 20)),
        _log(DateTime(2026, 9, 15), 1, updatedAt: DateTime(2026, 9, 15, 9)),
      ]);

      expect(find.byKey(AppKeys.practiceHeatmapEmpty), findsNothing);
      expect(find.text('通算 3回'), findsOneWidget);
      expect(find.text('一番多い時間帯: 夜'), findsOneWidget);

      // 28セル全部
      var cellCount = 0;
      for (var w = 1; w <= 7; w++) {
        for (var b = 0; b < 4; b++) {
          expect(
            find.byKey(Key('practice_heatmap_cell_${w}_$b')),
            findsOneWidget,
            reason: 'cell w=$w b=$b',
          );
          cellCount++;
        }
      }
      expect(cellCount, 28);

      // 濃淡セル: 月曜band3は2回（最高濃度）
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('practice_heatmap_cell_1_3')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(
        decoration.color!.withValues(alpha: 1).computeLuminance(),
        lessThan(0.6),
      );
    });
  });

  group('HabitCalendarScreen 配線試練', () {
    // 基準日: 2026-09-15（火）12:00
    final now = DateTime(2026, 9, 15, 12, 0);

    void useTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> pumpScreen(
      WidgetTester tester,
      List<PracticeLog> logs,
    ) async {
      final taskVM = TaskViewModel(
        _MockTaskRepository(),
        PlayerViewModel(_MockPlayerRepository()),
      );
      await taskVM.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<TaskViewModel>.value(
          value: taskVM,
          child: MaterialApp(
            home: HabitCalendarScreen(
              repository: _FakeReflectionRepository(),
              practiceLogRepository: _FakePracticeLogRepository(logs),
              now: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('practiceHeatmapSection がカレンダー最下部に表示される',
        (tester) async {
      useTallViewport(tester);
      await pumpScreen(tester, [
        _log(DateTime(2026, 9, 14), 1, updatedAt: DateTime(2026, 9, 14, 21)),
      ]);

      expect(find.byKey(AppKeys.practiceHeatmapSection), findsOneWidget);
      expect(find.byKey(AppKeys.practiceHeatmapEmpty), findsNothing);
      // 既存要素がまだ生きていること（押し出されていない）
      expect(find.byKey(const Key('habit_calendar_summary')), findsOneWidget);
      expect(find.byKey(const Key('habit_goal_reminder')), findsOneWidget);
    });

    testWidgets('ログ0件でも section は出て空状態になる', (tester) async {
      useTallViewport(tester);
      await pumpScreen(tester, const []);

      expect(find.byKey(AppKeys.practiceHeatmapSection), findsOneWidget);
      expect(find.byKey(AppKeys.practiceHeatmapEmpty), findsOneWidget);
    });
  });
}