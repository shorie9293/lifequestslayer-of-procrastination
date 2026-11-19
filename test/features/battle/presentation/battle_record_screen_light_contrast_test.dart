// ライトテーマ実描画のコントラスト走査：討伐戦績画面（battle_record_screen）。
//
// 背景 #F7F3E8（和紙白）に対して、実描画された RenderParagraph の実効色／
// 実効背景（半透明は alphaBlend で合成）から比を出し、3.0:1 未満が 0 件を撃つ。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

BattleRecord _rec(
  String id,
  DateTime at, {
  bool victory = true,
  int combo = 0,
  int remaining = 0,
  String title = 'クエスト',
}) =>
    BattleRecord(
      id: id,
      title: title,
      occurredAt: at,
      isVictory: victory,
      comboCount: combo,
      remainingSubTasks: remaining,
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  final seen = <RenderObject>{};
  element.visitAncestorElements((ancestor) {
    final ro = ancestor.renderObject;
    if (ro == null || !seen.add(ro)) return true;
    if (ro is RenderDecoratedBox) {
      final d = ro.decoration;
      if (d is BoxDecoration) {
        if (d.color != null) {
          layers.add(d.color!);
        } else if (d.gradient case final LinearGradient g
            when g.colors.isNotEmpty) {
          // グラデーション面は上端色で近似する。
          layers.add(g.colors.first);
        }
      }
    }
    return true;
  });
  var bg = scaffoldColor;
  for (final layer in layers.reversed) {
    bg = Color.alphaBlend(layer, bg);
  }
  return bg;
}

bool _measurable(String text) => RegExp(r'[0-9A-Za-z\u3040-\u30FF\u4E00-\u9FFF'
        r'\u3001-\u303F\uFF01-\uFF60]')
    .hasMatch(text);

class _Scan {
  int measurable = 0;
  int violations = 0;
  double minRatio = 99;
  String worst = '';
  final List<String> details = [];

  @override
  String toString() {
    final base = 'measurable=$measurable violations=$violations '
        'min=${minRatio.toStringAsFixed(2)}:1 ($worst)';
    if (details.isEmpty) return base;
    return '$base\n  ${details.join('\n  ')}';
  }
}

_Scan _scan(WidgetTester tester) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final scaffold = app.theme!.scaffoldBackgroundColor;
  final fallback = app.theme!.textTheme.bodyMedium?.color ?? Colors.black;
  final scan = _Scan();
  final seen = <String>{};
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
    if (ratio < scan.minRatio) {
      scan.minRatio = ratio;
      scan.worst = '"$plain"';
    }
    if (ratio < 3.0 && seen.add(plain)) {
      scan.violations++;
      scan.details.add(
          '${ratio.toStringAsFixed(2)}:1 "$plain" fg=#${raw.toARGB32().toRadixString(16).padLeft(8, '0')} bg=#${bg.toARGB32().toRadixString(16).padLeft(8, '0')}');
    }
  }
  return scan;
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  final repo = InMemoryBattleRecordRepository();
  final base = DateTime(2026, 5, 1, 12);
  for (int i = 0; i < 10; i++) {
    await repo.add(_rec(
      'r$i',
      base.add(Duration(hours: i)),
      victory: i % 3 != 0,
      combo: i % 4,
      remaining: i % 3,
      title: 'クエスト${i + 1}',
    ));
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: BattleRecordScreen(
        repository: repo,
        now: DateTime(2026, 5, 31, 12),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('討伐戦績: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });
}
