// 親探針: ライトテーマのコントラスト走査が「空振りで緑」になっていないことを撃つ。
//
// - 走査対象の文字（measurable）が実際に十分な件数あること（母数の実測）
// - ライト/ダーク双方で 3.0:1 未満が 0 件であること
// - ダークの見た目が退行していないこと（本文の実効色が明背景になっていない）
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/gryphon_report.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/town/data/gryphon_report_repository.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';

class _InMemoryReports extends GryphonReportRepository {
  @override
  Future<void> save(GryphonReport report) async {}

  @override
  Future<List<GryphonReport>> getAll() async => <GryphonReport>[];

  @override
  Future<void> clearAll() async {}
}

Reflection _reflection(int index, DateTime date) => Reflection(
      id: 'p$index',
      taskId: 'task-$index',
      date: date,
      content: '振り返り本文$index',
      selfDifficulty: 1 + (index % 5),
      aiDifficulty: QuestRank.values[index % QuestRank.values.length],
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
      if (d is BoxDecoration && d.color != null) layers.add(d.color!);
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

  @override
  String toString() =>
      'measurable=$measurable violations=$violations min=${minRatio.toStringAsFixed(2)}:1 ($worst)';
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
    if (ratio < 3.0 && seen.add(plain)) scan.violations++;
  }
  return scan;
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: ReflectionGroveScreen(
        onBack: () {},
        reportRepository: _InMemoryReports(),
      ),
    ),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_parent_probe_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('親探針1: ライト走査は母数を持ち、3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = ReflectionRepository();
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
      final base = DateTime(2026, 1, 1, 12);
      for (int i = 0; i < 12; i++) {
        await repo.save(_reflection(i, base.subtract(Duration(minutes: i))));
      }
    });

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(40),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('親探針2: ダークは退行していない（母数あり・3.0:1 未満 0 件）',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = ReflectionRepository();
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
      final base = DateTime(2026, 1, 1, 12);
      for (int i = 0; i < 12; i++) {
        await repo.save(_reflection(i, base.subtract(Duration(minutes: i))));
      }
    });

    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(40));
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
  });
}
