// ボタン契約のコントラスト試練（全ジョブ × ライト／ダーク）。
//
// 欠陥（既知）: ライトの既定 ElevatedButton / FilledButton は前景に primary
// （金 #D4A038）を採り、和紙白地で 2.13:1。style 未指定のボタンが読めない。
//
// 本試練は「テーマ契約」と「実描画」の両面から撃つ。
// - テーマ: ElevatedButtonTheme / FilledButtonTheme / OutlinedButtonTheme /
//   TextButtonTheme の解決済み前景 ↔ 塗り面が 4.5:1 以上（ライト・全4ジョブ）
// - 実描画: 4種のボタンを pump し、ラベルの RenderParagraph の実効色を
//   祖先 Material の塗りと合成して比を測る（measurable 母数 assert 付き）
// - ダーク退行なし: ダークのテーマには ButtonStyle を一切注入していない
//   （＝既定のまま）ことと、ライト専用の墨色/濃金が漏れていないことを撃つ
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── 測定ヘルパ ──────────────────────────────────────────

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 文字が載っている実効背景（外側から合成。ボタンは内側 Material.color が塗り）。
Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is ColoredBox) {
      layers.add(w.color);
    } else if (w is Material && w.color != null) {
      layers.add(w.color!);
    } else if (w is DecoratedBox) {
      final d = w.decoration;
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

/// ボタンラベルの実効コントラストを走査する。
_Scan _scan(WidgetTester tester) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final scaffold = app.theme!.scaffoldBackgroundColor;
  final scan = _Scan();
  for (final element in tester.allElements) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph) continue;
    if (ro.debugNeedsLayout) continue;
    final plain = ro.text.toPlainText();
    if (plain.isEmpty) continue;
    final bg = _effectiveBackground(element, scaffold);
    final raw = ro.text.style?.color ?? Colors.black;
    final eff = Color.alphaBlend(raw, bg);
    final ratio = _contrast(eff, bg);
    scan.measurable++;
    scan.colors.add(raw.toARGB32());
    if (ratio < scan.minRatio) {
      scan.minRatio = ratio;
      scan.worst = '"$plain"';
    }
    if (ratio < 4.5) {
      scan.violations++;
      scan.details.add('"$plain"=${ratio.toStringAsFixed(2)}:1 '
          'fg=${raw.toARGB32().toRadixString(16)} '
          'bg=${bg.toARGB32().toRadixString(16)}');
    }
  }
  return scan;
}

// ── pump ────────────────────────────────────────────────

Future<void> _pumpButtons(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('昇格ボタン')),
              FilledButton(onPressed: () {}, child: const Text('塗りボタン')),
              OutlinedButton(onPressed: () {}, child: const Text('枠線ボタン')),
              TextButton(onPressed: () {}, child: const Text('文字ボタン')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Color? _resolvedForeground(ThemeData theme, String kind) {
  final style = switch (kind) {
    'elevated' => theme.elevatedButtonTheme.style,
    'filled' => theme.filledButtonTheme.style,
    'outlined' => theme.outlinedButtonTheme.style,
    'text' => theme.textButtonTheme.style,
    _ => null,
  };
  return style?.foregroundColor?.resolve(<WidgetState>{});
}

Color? _resolvedBackground(ThemeData theme, String kind) {
  final style = switch (kind) {
    'elevated' => theme.elevatedButtonTheme.style,
    'filled' => theme.filledButtonTheme.style,
    _ => null,
  };
  return style?.backgroundColor?.resolve(<WidgetState>{});
}

void main() {
  group('ボタン契約（テーマ解決値）', () {
    for (final job in Job.values) {
      testWidgets('ライト ${job.name}: 前景 ↔ 塗り面が 4.5:1 以上', (tester) async {
        final theme = GameThemes.lightForJob(job);

        // 昇格ボタン: 面 = surface / 前景 = 濃墨
        final elevBg = _resolvedBackground(theme, 'elevated');
        final elevFg = _resolvedForeground(theme, 'elevated');
        expect(elevBg, isNotNull, reason: '昇格ボタンの塗り面が未定義');
        expect(elevFg, isNotNull, reason: '昇格ボタンの前景が未定義');
        final elevRatio = _contrast(elevFg!, elevBg!);

        // 塗りボタン: 面 = primary 系 / 前景 = 4.5:1 を満たす色
        final fillBg = _resolvedBackground(theme, 'filled');
        final fillFg = _resolvedForeground(theme, 'filled');
        expect(fillBg, isNotNull, reason: '塗りボタンの塗り面が未定義');
        expect(fillFg, isNotNull, reason: '塗りボタンの前景が未定義');
        final fillRatio = _contrast(fillFg!, fillBg!);

        // 枠線・文字ボタンは地（scaffold / surface）に対して測る。
        final ground = theme.colorScheme.surface;
        final outlinedRatio = _contrast(_resolvedForeground(theme, 'outlined')!, ground);
        final textRatio = _contrast(_resolvedForeground(theme, 'text')!, ground);

        // ignore: avoid_print
        print('BUTTON THEME LIGHT ${job.name}: elevated=${elevRatio.toStringAsFixed(2)} '
            'filled=${fillRatio.toStringAsFixed(2)} '
            'outlined=${outlinedRatio.toStringAsFixed(2)} '
            'text=${textRatio.toStringAsFixed(2)} '
            'fill=${fillBg.toARGB32().toRadixString(16)} '
            'onFill=${fillFg.toARGB32().toRadixString(16)}');

        expect(elevRatio, greaterThanOrEqualTo(4.5),
            reason: '昇格ボタンが読めない: ${elevRatio.toStringAsFixed(2)}:1');
        expect(fillRatio, greaterThanOrEqualTo(4.5),
            reason: '塗りボタンが読めない: ${fillRatio.toStringAsFixed(2)}:1');
        expect(outlinedRatio, greaterThanOrEqualTo(4.5),
            reason: '枠線ボタンが読めない: ${outlinedRatio.toStringAsFixed(2)}:1');
        expect(textRatio, greaterThanOrEqualTo(4.5),
            reason: '文字ボタンが読めない: ${textRatio.toStringAsFixed(2)}:1');
      });
    }
  });

  group('ボタン実描画', () {
    for (final job in Job.values) {
      testWidgets('ライト ${job.name}: 実描画で 4.5:1 未満が 0 件', (tester) async {
        await _pumpButtons(tester, GameThemes.lightForJob(job));
        final scan = _scan(tester);
        // ignore: avoid_print
        print('BUTTON RENDER LIGHT ${job.name}: $scan');
        expect(scan.measurable, greaterThanOrEqualTo(4),
            reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
        expect(scan.violations, 0, reason: 'ライトで読めないボタン: $scan');
      });

      testWidgets('ダーク ${job.name}: テーマに ButtonStyle を注入していない', (tester) async {
        final theme = GameThemes.forJob(job);
        expect(theme.elevatedButtonTheme.style, isNull,
            reason: 'ダークの昇格ボタン既定を書き換えている（見た目退行）');
        expect(theme.filledButtonTheme.style, isNull,
            reason: 'ダークの塗りボタン既定を書き換えている（見た目退行）');
        expect(theme.outlinedButtonTheme.style, isNull,
            reason: 'ダークの枠線ボタン既定を書き換えている（見た目退行）');
        expect(theme.textButtonTheme.style, isNull,
            reason: 'ダークの文字ボタン既定を書き換えている（見た目退行）');

        await _pumpButtons(tester, theme);
        final scan = _scan(tester);
        // ignore: avoid_print
        print('BUTTON RENDER DARK ${job.name}: $scan');
        expect(scan.measurable, greaterThanOrEqualTo(4));
        for (final argb in const [0xFF1A1A1A, 0xFF7A5200]) {
          expect(scan.colors.contains(argb), isFalse,
              reason: 'ダークにライト専用色 ${argb.toRadixString(16)} が漏れている');
        }
      });
    }
  });
}
