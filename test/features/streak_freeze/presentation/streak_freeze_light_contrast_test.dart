// ライトテーマ実描画のコントラスト走査（連続記録お休み券）。
//
// 提案カード（琥珀/灰地）・注記の灰文字・赤字の不足ラベルは
// ダーク前提のリテラルで書かれており、和紙白のライトでは読めない疑いがある。
// 実描画から実効背景に合成して 3.0:1 を門にする。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/streak_freeze/data/streak_freeze_repository.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_screen.dart';

// ── DI モック ────────────────────────────────────────────

class _FakePlayerRepository implements IPlayerRepository {
  _FakePlayerRepository(this._player);
  Player? _player;
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

final DateTime _now = DateTime(2026, 10, 20, 9);

/// 1日休んで連続記録が途切れたプレイヤー（券の使用提案が出る）。
PlayerViewModel _brokenVm() {
  final player = Player(
    streakDays: 12,
    longestStreak: 20,
    lastLoginDate: DateTime(2026, 10, 18, 9),
  );
  final vm = PlayerViewModel(_FakePlayerRepository(player));
  vm.player = player;
  vm.checkAndResetMissions(_now, login: true);
  return vm;
}

// ── 走査ハーネス（各試練ファイルへ複製する。共用ヘルパにしない） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

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

// ── pump ────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required int tickets,
  required bool withHistory,
}) async {
  final state = StreakFreezeState(
    tickets: tickets,
    history: withHistory
        ? [
            StreakFreezeUsage(
              usedAt: DateTime(2026, 10, 5, 21, 30),
              coveredMissedDays: 1,
              keptStreak: 14,
            ),
          ]
        : const [],
  );
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: StreakFreezeScreen(
      repository: InMemoryStreakFreezeRepository(state),
      playerViewModel: _brokenVm(),
      clock: () => _now,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void _useViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('お休み券: ライト実描画で 3.0:1 未満が 0 件（提案あり）', (tester) async {
    _useViewport(tester);
    await _pump(tester, GameThemes.lightForJob(Job.adventurer),
        tickets: 2, withHistory: true);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('STREAK FREEZE LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(8),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('お休み券: ライトで券不足ラベルも 3.0:1 以上', (tester) async {
    _useViewport(tester);
    await _pump(tester, GameThemes.lightForJob(Job.adventurer),
        tickets: 0, withHistory: false);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('STREAK FREEZE LIGHT INSUFFICIENT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(6));
    expect(scan.violations, 0, reason: 'ライト（券不足）で読めない文字: $scan');
  });

  testWidgets('お休み券: ダークで違反 0 件・墨色の漏れなし', (tester) async {
    _useViewport(tester);
    await _pump(tester, GameThemes.forJob(Job.adventurer),
        tickets: 2, withHistory: true);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('STREAK FREEZE DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(8));
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A, 0xFF6B6B6B]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
