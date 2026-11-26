// クエスト検索画面のライト実描画コントラスト走査。
//
// - 走査母数（measurable）を assert ＝ 空振り緑の排除
// - ライトで 3.0:1 未満が 0 件
// - ダークで違反 0 件＋ライト専用の墨色が漏れていないこと
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── 走査ハーネス（他担当と共用しない。各試練ファイルへ複製する） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _darkestOf(List<Color> colors) =>
    colors.reduce((a, b) => a.computeLuminance() <= b.computeLuminance() ? a : b);

Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox) {
      final d = widget.decoration;
      if (d is BoxDecoration) {
        if (d.gradient != null && d.gradient!.colors.isNotEmpty) {
          layers.add(_darkestOf(d.gradient!.colors));
        } else if (d.color != null) {
          layers.add(d.color!);
        }
      }
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
      scan.details.add('"$plain"=${ratio.toStringAsFixed(2)}:1 '
          'fg=${raw.toARGB32().toRadixString(16)} '
          'bg=${bg.toARGB32().toRadixString(16)}');
    }
  }
  return scan;
}

// ── データ（既存試練の 12 件を踏襲） ─────────────────────

final DateTime _now = DateTime(2026, 9, 22, 12, 0, 0);

Task _task(
  String id,
  String title, {
  QuestRank rank = QuestRank.B,
  DateTime? deadline,
  int? targetTimeMinutes,
  List<String> tags = const [],
}) {
  return Task(
    id: id,
    title: title,
    rank: rank,
    deadline: deadline,
    targetTimeMinutes: targetTimeMinutes,
    tags: tags,
  );
}

List<Task> _sampleTasks() => [
      _task('t01', 'ゴブリン討伐',
          deadline: _now.add(const Duration(days: 1)),
          targetTimeMinutes: 30,
          tags: ['戦闘']),
      _task('t02', 'ドラゴン討伐',
          rank: QuestRank.S,
          deadline: _now.add(const Duration(days: 7)),
          targetTimeMinutes: 600,
          tags: ['戦闘', '冒険']),
      _task('t03', '薬草採取',
          rank: QuestRank.A, targetTimeMinutes: 120, tags: ['採集']),
      _task('t04', '書物の写経', targetTimeMinutes: 90, tags: ['学問']),
      _task('t05', '村の見回り', rank: QuestRank.A),
      _task('t06', 'ガレージ掃除',
          deadline: _now.subtract(const Duration(days: 2))),
      _task('t07', '報告書作成', targetTimeMinutes: 60),
      _task('t08', '剣術の修行', rank: QuestRank.S, targetTimeMinutes: 300),
      _task('t09', '井戸の清掃', rank: QuestRank.A, targetTimeMinutes: 45),
      _task('t10', '手紙の配達', targetTimeMinutes: 15),
      _task('t11', '期限切れの納税',
          rank: QuestRank.A,
          deadline: _now.subtract(const Duration(hours: 1))),
      _task('t12', '境界の同時刻クエスト', deadline: _now),
    ];

// ── pump ────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: GuildQuestSearchScreen(tasksOverride: _sampleTasks(), now: _now),
    ),
  );
  // pumpAndSettle 不可（TaskCard のカウントダウン等で固まり得る）。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('クエスト検索: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('GUILD QUEST SEARCH LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(5),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('クエスト検索: ダークで違反 0 件・墨色の漏れなし', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('GUILD QUEST SEARCH DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(5));
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
    for (final argb in const [
      0xFF2B2B2B,
      0xFF4A4A4A,
      0xFF5A5A5A,
      0xFF6B6B6B,
    ]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
