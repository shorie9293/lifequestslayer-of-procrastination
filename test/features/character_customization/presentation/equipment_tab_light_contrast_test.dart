// ライトテーマ実描画のコントラスト走査（キャラクター装備タブ）。
//
// 直書き色リテラル（Colors.white / white54 / white38 / black54 等）を
// GamePalette トークンへ寄せた結果、和紙白（#F7F3E8）地に対して
// 読めない文字が 0 件であることを実描画から撃つ。
//
// - 走査対象（measurable）が十分な母数あること＝空振りで緑になっていないこと
// - ライトで 3.0:1 未満が 0 件（初期表示・スキン一覧・プレビュー選択の3状態）
// - ダークでは従来の白系文字が保たれていること（ライト墨色へ退行していない）
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/features/character_customization/presentation/equipment_tab.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

// ── 走査ハーネス（他担当と共用しない。各試練ファイルへ複製する） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _darkestOf(List<Color> colors) => colors
    .reduce((a, b) => a.computeLuminance() <= b.computeLuminance() ? a : b);

/// 祖先の塗り（BoxDecoration / グラデーション / ColoredBox / Material / Chip）を
/// 外側から合成し、文字が実際に載っている実効背景色を求める。
Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox) {
      final d = widget.decoration;
      if (d is BoxDecoration) {
        if (d.gradient != null && d.gradient!.colors.isNotEmpty) {
          // グラデーションは d.color ではなく gradient が描く。
          // 最も暗い停止色を採る（暗背景の白文字＝高コントラスト側に倒さない保守側）。
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
      // Chip の背景は Material.color ではなく _RenderChip.paint が描く
      // （SDK chip.dart:1404 の Material は color を渡さない）ため、ここで拾う。
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
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: EquipmentTab(
          currentSkin: const CharacterSkin(),
          playerLevel: 50,
          streakDays: 30,
          totalTasks: 100,
          titles: const ['伝説の討伐者'],
          onEquip: (_, __) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// スキン一覧を開く（「鎧」スロット）。解放済み・未解放の両方が並ぶ。
Future<void> _openArmorList(WidgetTester tester) async {
  await tester.tap(find.text('鎧'), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('装備タブ: ライト初期表示で 3.0:1 未満が 0 件', (tester) async {
    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('EQUIP LIGHT EMPTY $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('装備タブ: ライトのスキン一覧で 3.0:1 未満が 0 件', (tester) async {
    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    await _openArmorList(tester);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('EQUIP LIGHT LIST $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: '一覧に読めない文字: $scan');
  });

  testWidgets('装備タブ: ライトでプレビュー選択しても 3.0:1 未満が 0 件', (tester) async {
    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    await _openArmorList(tester);
    await tester.tap(find.text('王家の鎧'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('EQUIP LIGHT PREVIEW $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30));
    expect(scan.violations, 0, reason: 'プレビュー選択後に読めない文字: $scan');
  });

  testWidgets('装備タブ: ダークは白系文字のまま（墨色へ退行していない）', (tester) async {
    await _pump(tester, GameThemes.forJob(Job.adventurer));
    await _openArmorList(tester);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('EQUIP DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30));
    expect(scan.colors, contains(0xFFFFFFFF), reason: 'ダークの白系文字が失われている');
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A, 0xFF6B6B6B]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
