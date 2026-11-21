// ライトテーマ実描画のコントラスト走査（計画の陣＝プロジェクト一覧）。
//
// 直書き色リテラル（Colors.grey / grey[400] / grey[500] 等）をテーマ明度で
// 解決する色へ差し替えた結果、和紙白（#F7F3E8）背景に対して読めない文字が
// 0 件であることを実描画から撃つ。
//
// - 走査対象（measurable）が十分な母数あること＝空振りで緑になっていないこと
// - ライトで 3.0:1 未満が 0 件
// - ダークでは従来の白系文字が保たれていること（ライト墨色へ退行していない）
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/project/presentation/project_list_screen.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── DI モック ────────────────────────────────────────────

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

Player _player({required bool unlocked}) => Player(
      currentJob: Job.mystic,
      jobLevels: {Job.mystic: unlocked ? 12 : 1},
      projects: unlocked
          ? [
              ProjectGroup(name: '計画P', taskIds: ['t1', 't2'], bonusExp: 50),
              ProjectGroup(name: '計画Q', taskIds: ['t3'], bonusExp: 10),
            ]
          : null,
      taskProjects:
          unlocked ? {'t1': '計画P', 't2': '計画P', 't3': '計画Q'} : null,
    );

List<Task> _tasks() => [
      Task(id: 't1', title: 'クエストt1', isCompleted: true),
      Task(id: 't2', title: 'クエストt2'),
      Task(id: 't3', title: 'クエストt3', isCompleted: true),
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

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required bool unlocked,
}) async {
  final vm = PlayerViewModel(_MockPlayerRepo());
  final player = _player(unlocked: unlocked);
  await vm.load();
  vm.player = player;

  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(
        theme: theme,
        home: ProjectListScreen(tasksOverride: _tasks()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('計画の陣: ライト実描画で 3.0:1 未満が 0 件（一覧）', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer), unlocked: true);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('PROJECT LIGHT list $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('計画の陣: ライト実描画で 3.0:1 未満が 0 件（空状態）', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = PlayerViewModel(_MockPlayerRepo());
    await vm.load();
    vm.player = Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 12});
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerViewModel>.value(
        value: vm,
        child: MaterialApp(
          theme: GameThemes.lightForJob(Job.adventurer),
          home: const ProjectListScreen(tasksOverride: []),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    final scan = _scan(tester);
    // ignore: avoid_print
    print('PROJECT LIGHT empty $scan');
    expect(scan.measurable, greaterThanOrEqualTo(3),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('計画の陣: ライト実描画で 3.0:1 未満が 0 件（未解放）', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer), unlocked: false);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('PROJECT LIGHT locked $scan');
    expect(scan.measurable, greaterThanOrEqualTo(2),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('計画の陣: ダークは墨色へ退行していない（白系文字のまま）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer), unlocked: true);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('PROJECT DARK list $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10));
    // ライト用の墨（#2B2B2B / #4A4A4A / #5A5A5A / #6B6B6B）が漏れていないこと。
    for (final argb in const [
      0xFF2B2B2B,
      0xFF4A4A4A,
      0xFF5A5A5A,
      0xFF6B6B6B
    ]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
