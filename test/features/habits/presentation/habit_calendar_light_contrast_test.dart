// ライトテーマ実描画のコントラスト走査（勤行の習慣カレンダー）。
//
// 「テーマ切替は選べるが読めない」を出荷しないための門。
// 既定（ダーク）だけでなく**逆テーマ（ライト）**で pump し、
// 実効背景に合成した文字色の比を 3.0:1 で判定する。
//
// - 走査母数（measurable）を assert ＝ 空振り緑の排除
// - ライトで 3.0:1 未満が 0 件
// - ダークで違反 0 件＋ライト専用の墨色が漏れていないこと
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

// ── DI モック ────────────────────────────────────────────

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
  _MockTaskRepository(this.tasks);
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

// ── 走査ハーネス（各試練ファイルへ複製する。共用ヘルパにしない） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox) {
      final d = widget.decoration;
      if (d is BoxDecoration && d.color != null) layers.add(d.color!);
    } else if (widget is ColoredBox) {
      layers.add(widget.color);
    } else if (widget is Material && widget.color != null) {
      layers.add(widget.color!);
    }
    return true;
  });
  var bg = scaffoldColor;
  for (final layer in layers.reversed) {
    bg = Color.alphaBlend(layer, bg);
  }
  return bg;
}

bool _measurable(String text) =>
    RegExp(r'[0-9A-Za-z\u3040-\u30FF\u4E00-\u9FFF]').hasMatch(text);

class _Scan {
  int measurable = 0;
  int violations = 0;
  double minRatio = 99;
  String worst = '';
  final Set<int> colors = <int>{};
  final List<String> details = <String>[];

  @override
  String toString() => 'measurable=$measurable violations=$violations '
      'min=${minRatio.toStringAsFixed(2)}:1 ($worst)'
      '${details.isEmpty ? '' : ' -> $details'}';
}

_Scan _scan(WidgetTester tester) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final scaffold = app.theme!.scaffoldBackgroundColor;
  final fallback = app.theme!.textTheme.bodyMedium?.color ?? Colors.black;
  final scan = _Scan();
  final counted = <String>{};
  for (final element in tester.allElements) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph) continue;
    if (ro.debugNeedsLayout) continue;
    final plain = ro.text.toPlainText();
    if (!_measurable(plain)) continue;
    final bg = _effectiveBackground(element, scaffold);
    final raw = ro.text.style?.color ?? fallback;
    final eff = Color.alphaBlend(raw, bg);
    final ratio = _contrast(eff, bg);
    scan.measurable++;
    scan.colors.add(raw.toARGB32());
    if (ratio < scan.minRatio) {
      scan.minRatio = ratio;
      scan.worst = '"$plain"';
    }
    if (ratio < 3.0 && counted.add(plain)) {
      scan.violations++;
      scan.details.add('"$plain"=${ratio.toStringAsFixed(2)}:1');
    }
  }
  return scan;
}

// ── データと pump ───────────────────────────────────────

final DateTime _now = DateTime(2026, 9, 15, 12);

Reflection _refl(DateTime date) => Reflection(
      id: 'r_${date.millisecondsSinceEpoch}',
      taskId: 't1',
      date: date,
      content: 'content',
      selfDifficulty: 3,
      aiDifficulty: QuestRank.A,
      sentiment: 'kaishin',
    );

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  bool withData = true,
}) async {
  final logs = withData
      ? <PracticeLog>[
          PracticeLog(date: DateTime(2026, 9, 1), count: 2),
          PracticeLog(date: DateTime(2026, 9, 8), count: 1),
          PracticeLog(date: DateTime(2026, 9, 14), count: 3),
          PracticeLog(date: DateTime(2026, 9, 15), count: 1),
        ]
      : const <PracticeLog>[];
  final reflections = withData
      ? <Reflection>[
          _refl(DateTime(2026, 9, 14)),
          _refl(DateTime(2026, 9, 15)),
        ]
      : const <Reflection>[];
  final taskVM = TaskViewModel(
    _MockTaskRepository([
      Task(id: 't1', title: 'quest', lastCompletedAt: DateTime(2026, 9, 15)),
    ]),
    PlayerViewModel(_MockPlayerRepository()),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<TaskViewModel>.value(
      value: taskVM,
      child: MaterialApp(
        theme: theme,
        home: HabitCalendarScreen(
          repository: _FakeReflectionRepository(reflections),
          practiceLogRepository: _FakePracticeLogRepository(logs),
          now: _now,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('勤行カレンダー: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    _useTallViewport(tester);
    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('HABIT CALENDAR LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(40),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('勤行カレンダー: ダークで違反 0 件・墨色の漏れなし', (tester) async {
    _useTallViewport(tester);
    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('HABIT CALENDAR DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(40));
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A, 0xFF6B6B6B]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });

  testWidgets('勤行カレンダー（記録なし）: ライトでも違反 0 件', (tester) async {
    _useTallViewport(tester);
    await _pump(tester, GameThemes.lightForJob(Job.adventurer), withData: false);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('HABIT CALENDAR LIGHT EMPTY $scan');
    expect(scan.measurable, greaterThanOrEqualTo(20));
    expect(scan.violations, 0, reason: 'ライト（空状態）で読めない文字: $scan');
  });
}
