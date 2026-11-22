// ErrorBoundary ライトテーマ実描画コントラスト走査。
//
// クラッシュ画面は地 Color(0xFF1E1A26) の自前ダークカード。
// 走査器が Material.color を拾えば violations=0 のはず。
//
// - 走査母数が十分にあること（空振り防止）
// - ライトテーマで 3.0:1 未満が 0 件
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/crash/error_boundary.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── 例外を投げる子 Widget ─────────────────────────────────

class _ThrowWidget extends StatelessWidget {
  const _ThrowWidget();

  @override
  Widget build(BuildContext context) {
    throw Exception('人工のクラッシュ（コントラスト走査用）');
  }
}

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

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    errors.add(details);
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: const ErrorBoundary(
          child: _ThrowWidget(),
        ),
      ),
    ),
  );
  // 1 回目: _ThrowWidget が throw → ErrorWidget.builder が _BoundaryFallbackBody を返す
  await tester.pump();
  // postFrameCallback が _error を設定 → 2 回目の build で _crashScreen() が返る
  await tester.pump(const Duration(milliseconds: 20));
  // restore error handler before teardown
  FlutterError.onError = previousOnError;
}

void main() {
  testWidgets('ErrorBoundary: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('ERROR_BOUNDARY LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(5),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('ErrorBoundary: ダーク実描画でも 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('ERROR_BOUNDARY DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(5));
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
  });
}
