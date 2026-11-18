// 振り返りの杜 — ライトテーマでの文字コントラスト回帰試練。
//
// ライトテーマ（和紙白 #F7F3E8 基調）では、ダーク前提の直書き白文字・金文字が
// 背景に溶けて読めなくなる。本試練は画面上の全 RenderParagraph を走査し、
// 実効色（半透明は直近背景へ alpha 合成）と、祖先の背景色を根から葉へ合成した
// 実効背景色とのコントラスト比を計算し、3.0:1 未満が 0 件であることを強制する。
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

/// 実Hiveを触らないメモリ実装（画面内の報告読込を完了させる）。
class _InMemoryGryphonReportRepository extends GryphonReportRepository {
  final List<GryphonReport> _reports = [];

  @override
  Future<void> save(GryphonReport report) async => _reports.add(report);

  @override
  Future<List<GryphonReport>> getAll() async =>
      [..._reports]..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

  @override
  Future<void> clearAll() async => _reports.clear();
}

Reflection _reflection(int index, DateTime date) {
  return Reflection(
    id: 'r$index',
    taskId: 'task-$index',
    date: date,
    content: '振り返り本文$index',
    selfDifficulty: 1 + (index % 5),
    aiDifficulty: QuestRank.values[index % QuestRank.values.length],
  );
}

/// WCAG 相対輝度に基づくコントラスト比。
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 祖先の背景色を根→葉の順に合成した実効背景色を返す。
///
/// Container → DecoratedBox のように複数 Element が同一 RenderObject を共有する
/// ため、RenderObject の同一性で重複を除く（さもないと半透明が多重合成される）。
Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  final seen = <RenderObject>{};
  element.visitAncestorElements((ancestor) {
    final ro = ancestor.renderObject;
    if (ro == null || !seen.add(ro)) return true;
    if (ro is RenderDecoratedBox) {
      final decoration = ro.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        layers.add(decoration.color!);
      }
    }
    return true;
  });
  var background = scaffoldColor;
  for (final layer in layers.reversed) {
    background = Color.alphaBlend(layer, background);
  }
  return background;
}

/// コントラスト測定に意味のある文字（英数・かな・漢字・和欧文句読点）を含むか。
/// 絵文字のみの Text は字形自体が有色で、前景色の指定に依らないため対象外。
bool _measurable(String text) => RegExp(r'[0-9A-Za-z\u3040-\u30FF\u4E00-\u9FFF'
        r'\u3001-\u303F\uFF01-\uFF60]')
    .hasMatch(text);

class _Violation {
  final String text;
  final Color color;
  final Color background;
  final double ratio;

  const _Violation(this.text, this.color, this.background, this.ratio);

  @override
  String toString() => '"$text" ${_hex(color)} on ${_hex(background)} '
      '= ${ratio.toStringAsFixed(2)}:1';
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// 画面上の全文字を走査し、3.0:1 未満のコントラスト違反を列挙する。
List<_Violation> _scanViolations(WidgetTester tester) {
  final scaffoldColor = tester
      .widget<MaterialApp>(find.byType(MaterialApp))
      .theme!
      .scaffoldBackgroundColor;
  final fallback = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .textTheme
          .bodyMedium
          ?.color ??
      const Color(0xFF000000);

  final violations = <_Violation>[];
  final seenText = <String>{};
  for (final element in tester.allElements) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph) continue;
    if (ro.debugNeedsLayout) continue;
    final plain = ro.text.toPlainText();
    if (!_measurable(plain)) continue;
    final style = ro.text.style;
    final raw = style?.color ?? fallback;
    final background = _effectiveBackground(element, scaffoldColor);
    final effective = Color.alphaBlend(raw, background);
    final ratio = _contrast(effective, background);
    if (ratio < 3.0) {
      // 同一文言・同一配色の重複描画は 1 件として数える。
      if (!seenText.add('$plain|${_hex(effective)}|${_hex(background)}')) {
        continue;
      }
      violations.add(_Violation(plain, effective, background, ratio));
    }
  }
  violations.sort((a, b) => a.ratio.compareTo(b.ratio));
  return violations;
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_grove_light_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> seed(WidgetTester tester, int count) async {
    final repo = ReflectionRepository();
    final base = DateTime(2026, 1, 1, 12);
    await tester.runAsync(() async {
      for (int i = 0; i < count; i++) {
        await repo.save(_reflection(i, base.subtract(Duration(minutes: i))));
      }
    });
  }

  Future<void> pumpGrove(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: GameThemes.lightForJob(Job.adventurer),
        home: ReflectionGroveScreen(
          onBack: () {},
          reportRepository: _InMemoryGryphonReportRepository(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('ライトテーマ: 空状態の全文字が 3.0:1 以上', (tester) async {
    await pumpGrove(tester);

    final violations = _scanViolations(tester);
    for (final v in violations) {
      // ignore: avoid_print
      print('VIOLATION $v');
    }
    expect(violations, isEmpty,
        reason: 'ライトテーマで 3.0:1 未満の文字が ${violations.length} 件: '
            '${violations.join(' / ')}');
  });

  testWidgets('ライトテーマ: 全セクション描画時も全文字が 3.0:1 以上', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seed(tester, 12);
    await pumpGrove(tester);

    final violations = _scanViolations(tester);
    for (final v in violations) {
      // ignore: avoid_print
      print('VIOLATION $v');
    }
    expect(violations, isEmpty,
        reason: 'ライトテーマで 3.0:1 未満の文字が ${violations.length} 件: '
            '${violations.join(' / ')}');
  });

  // ── テーマ側の文字色契約 ────────────────────────────────
  // Material が塗る面（FilledButton の地色等）は RenderDecoratedBox ではないため
  // 上の走査では背景を解決できない。その分は colorScheme の契約で担保する。
  test('ライトテーマの文字色契約: onSurface / onPrimary が各面で 3.0:1 以上', () {
    for (final job in Job.values) {
      final theme = GameThemes.lightForJob(job);
      final scheme = theme.colorScheme;
      final onSurface =
          _contrast(scheme.onSurface, theme.scaffoldBackgroundColor);
      final onSurfaceCard = _contrast(scheme.onSurface, scheme.surface);
      final onPrimary = _contrast(scheme.onPrimary, scheme.primary);
      // ignore: avoid_print
      print('${job.name}: onSurface=$onSurface onSurface(surface)='
          '$onSurfaceCard onPrimary=$onPrimary');

      expect(theme.brightness, Brightness.light);
      expect(onSurface, greaterThanOrEqualTo(4.5),
          reason: '${job.name}: onSurface が地色に対して不足');
      expect(onSurfaceCard, greaterThanOrEqualTo(4.5),
          reason: '${job.name}: onSurface が surface に対して不足');
      expect(onPrimary, greaterThanOrEqualTo(3.0),
          reason: '${job.name}: onPrimary が primary に対して不足');
      // 本文の既定色はダーク系（輝度 0.3 未満）であること。
      expect(
          theme.textTheme.bodyMedium!.color!.computeLuminance(), lessThan(0.3));
    }
  });
}
