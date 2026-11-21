// ライトテーマ実描画のコントラスト走査（俯瞰の魔眼）。
//
// 直書き色リテラル（amber[300] / grey[850] / grey[900] / grey[400] 等）を
// テーマ明度で解決する色へ差し替えた結果、和紙白（#F7F3E8）背景に対して
// 読めない文字が 0 件であることを実描画から撃つ。
//
// - 走査対象（measurable）が十分な母数あること＝空振りで緑になっていないこと
// - ライトで 3.0:1 未満が 0 件
// - ダークでは従来の白系文字が保たれていること（ライト墨色へ退行していない）
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/overview/presentation/screens/overview_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── DI モック ────────────────────────────────────────────

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _MockTaskRepository implements ITaskRepository {
  final List<Task> _tasks;
  _MockTaskRepository(this._tasks);

  @override
  Future<List<Task>> loadTasks() async => _tasks;
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

List<Task> _tasks() => [
      Task(
        id: 't1',
        title: '期限付きクエストA',
        deadline: DateTime(2026, 6, 1),
        rank: QuestRank.S,
      ),
      Task(
        id: 't2',
        title: '期限付きクエストB',
        deadline: DateTime(2026, 6, 1),
        rank: QuestRank.A,
        isCompleted: true,
      ),
      Task(
        id: 't3',
        title: '期限なしクエスト',
        status: TaskStatus.active,
        rank: QuestRank.B,
      ),
      Task(id: 't4', title: '現役クエスト', status: TaskStatus.active),
      Task(id: 't5', title: '掲示板クエスト', status: TaskStatus.inGuild),
      Task(id: 't6', title: '期限付きクエストC', deadline: DateTime(2026, 6, 2)),
    ];

// ── 走査ハーネス（他担当と共用しない。各試練ファイルへ複製する） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 祖先の塗り（BoxDecoration / ColoredBox / Material）を外側から合成し、
/// 文字が実際に載っている実効背景色を求める。
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

  void merge(_Scan other) {
    measurable += other.measurable;
    violations += other.violations;
    if (other.minRatio < minRatio) {
      minRatio = other.minRatio;
      worst = other.worst;
    }
    colors.addAll(other.colors);
    details.addAll(other.details);
  }

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

// ── pump ────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  bool unlocked = true,
}) async {
  final player = unlocked
      ? Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 15})
      : Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 1});
  final playerVM = PlayerViewModel(_MockPlayerRepository(player));
  await playerVM.load();
  final taskVM = TaskViewModel(_MockTaskRepository(_tasks()), playerVM);
  await taskVM.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
      ],
      child: MaterialApp(theme: theme, home: const OverviewScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('俯瞰の魔眼: ライト実描画で 3.0:1 未満が 0 件（暦＋カンバン）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final calendar = _scan(tester);
    // ignore: avoid_print
    print('OVERVIEW LIGHT calendar $calendar');

    await tester.tap(find.text('カンバン'));
    await tester.pumpAndSettle();
    final kanban = _scan(tester);
    // ignore: avoid_print
    print('OVERVIEW LIGHT kanban $kanban');

    calendar.merge(kanban);
    // ignore: avoid_print
    print('OVERVIEW LIGHT total $calendar');
    expect(calendar.measurable, greaterThanOrEqualTo(20),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(calendar.violations, 0, reason: 'ライトで読めない文字: $calendar');
  });

  testWidgets('俯瞰の魔眼: ライト実描画で 3.0:1 未満が 0 件（未解放）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer),
        unlocked: false);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('OVERVIEW LIGHT locked $scan');
    expect(scan.measurable, greaterThanOrEqualTo(2),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('俯瞰の魔眼: ダークは墨色へ退行していない（白系文字のまま）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final calendar = _scan(tester);
    // ignore: avoid_print
    print('OVERVIEW DARK calendar $calendar');

    await tester.tap(find.text('カンバン'));
    await tester.pumpAndSettle();
    final kanban = _scan(tester);
    // ignore: avoid_print
    print('OVERVIEW DARK kanban $kanban');

    calendar.merge(kanban);
    // ignore: avoid_print
    print('OVERVIEW DARK total $calendar');
    expect(calendar.measurable, greaterThanOrEqualTo(20));
    // ライト用の墨（#2B2B2B / #4A4A4A / #5A5A5A / #6B6B6B）が漏れていないこと。
    for (final argb in const [
      0xFF2B2B2B,
      0xFF4A4A4A,
      0xFF5A5A5A,
      0xFF6B6B6B
    ]) {
      expect(calendar.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
