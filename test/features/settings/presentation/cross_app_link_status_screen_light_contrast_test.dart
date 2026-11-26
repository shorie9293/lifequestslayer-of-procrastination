// 連携状況画面のライト実描画コントラスト走査。
//
// - 走査母数（measurable）を assert ＝ 空振り緑の排除
// - ライトで 3.0:1 未満が 0 件
// - ダークで違反 0 件＋ライト専用の墨色が漏れていないこと
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/settings/presentation/cross_app_link_status_screen.dart';
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

// ── pump ────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  // 記録口は fake async ゾーン内（= testWidgets 本体）で作る。
  final recorder = CrossAppLinkStatusRecorder(
    store: InMemoryCrossAppLinkStatusStore(),
    now: () => DateTime(2026, 11, 27, 9, 12),
  );
  await recorder.recordFolderReady(true);
  await recorder.recordSent(count: 3, fileName: 'tsundoku_reward_events.jsonl');
  await recorder.recordReceiveFailure(
    StateError('共有フォルダが読めません'),
    fileName: 'kozuchi_quest.json',
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: CrossAppLinkStatusScreen(recorder: recorder),
    ),
  );
  // 読込中（CircularProgressIndicator）があるため pumpAndSettle は使わない。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('連携状況: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('CROSS APP LINK LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(5),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('連携状況: ダークで違反 0 件・墨色の漏れなし', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('CROSS APP LINK DARK $scan');
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
