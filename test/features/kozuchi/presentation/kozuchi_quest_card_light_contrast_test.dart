// KozuchiQuestCard ライトテーマ実描画コントラスト走査。
//
// 札の地色 Color(0xFF1A0A2E) は自前の暗色であり、走査器が
// Card → Material.color および内側の DecoratedBox(BoxDecoration gradient) を
// 正しく合成すれば violations=0 になるはず。
//
// - 走査母数が十分にあること（空振り防止）
// - ライトテーマで 3.0:1 未満が 0 件
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/presentation/widgets/kozuchi_quest_card.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── 走査ハーネス（guild_screen_light_contrast_test.dart から複製） ──

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
    } else if (widget is RawChip && widget.backgroundColor != null) {
      layers.add(widget.backgroundColor!);
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

// ── pump ────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, ThemeData theme, KozuchiQuest quest) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: KozuchiQuestCard(quest: quest),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

KozuchiQuest _makeQuest({bool isCompleted = false}) => KozuchiQuest(
  title: '英気を養う読書の時間',
  description: '毎日15分、好きな本を読んで心を豊かにする試練です。スマホを脇に置いて集中しましょう。',
  suggestedOffering: 500,
  advisorEmoji: '🪘',
  advisorLabel: 'ライフプランナー',
  isCompleted: isCompleted,
);

void main() {
  testWidgets('KozuchiQuestCard: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer), _makeQuest());
    final scan = _scan(tester);
    // ignore: avoid_print
    print('KOZUCHI LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('KozuchiQuestCard: ライト実描画・達成済みでも 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      GameThemes.lightForJob(Job.adventurer),
      _makeQuest(isCompleted: true),
    );
    final scan = _scan(tester);
    // ignore: avoid_print
    print('KOZUCHI LIGHT DONE $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10));
    expect(scan.violations, 0, reason: 'ライト（達成済み）で読めない文字: $scan');
  });

  testWidgets('KozuchiQuestCard: ダーク実描画でも 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer), _makeQuest());
    final scan = _scan(tester);
    // ignore: avoid_print
    print('KOZUCHI DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10));
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
  });
}
