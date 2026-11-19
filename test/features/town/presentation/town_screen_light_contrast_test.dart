// ライトテーマ実描画のコントラスト走査（町タブ）。
//
// 直書き色リテラルを GamePalette トークンへ差し替えた結果、
// 和紙白（#F7F3E8）背景に対して読めない文字が 0 件であることを実描画から撃つ。
//
// - 走査対象（measurable）が十分な母数あること＝空振りで緑になっていないこと
// - ライトで 3.0:1 未満が 0 件
// - ダークでは従来の白系文字が保たれていること（ライト墨色へ退行していない）
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';

// ── DI モック ────────────────────────────────────────────

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _MockTaskRepository implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

class _MockSettingsRepository extends SettingsRepository {
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<void> setFontSizeScale(double scale) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<void> setKnowledgeQuestEnabled(bool enabled) async {}
  @override
  Future<void> saveFatiguePopupDate(DateTime date) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool value) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<void> setTutorialChoiceMade(bool value) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setJobTutorialCompleted(bool value) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => true;
  @override
  Future<double> getSfxVolume() async => 0.7;
  @override
  Future<void> setSfxVolume(double volume) async {}
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => true;
  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

// ── 走査ハーネス（他担当と共用しない。各試練ファイルへ複製する） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 祖先の塗り（BoxDecoration / ColoredBox / Material）を外側から合成し、
/// 文字が実際に載っている実効背景色を求める。
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

Future<(GameViewModel, PlayerViewModel, TownViewModel)>
    _buildViewModels() async {
  final playerVM = PlayerViewModel(
    _MockPlayerRepository(Player(jobLevels: {Job.adventurer: 5})),
  );
  await playerVM.load();
  final townVM = TownViewModel();
  townVM.initialize();
  final vm = GameViewModel(
    pr: _MockPlayerRepository(Player(jobLevels: {Job.adventurer: 5})),
    tr: _MockTaskRepository(),
    sr: _MockSettingsRepository(),
    tv: townVM,
  );
  final start = DateTime.now();
  while (!vm.isLoaded) {
    if (DateTime.now().difference(start) > const Duration(seconds: 5)) {
      throw Exception('GameViewModel のロードがタイムアウトしました');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return (vm, playerVM, townVM);
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  GameViewModel vm,
  PlayerViewModel playerVM,
  TownViewModel townVM,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameViewModel>.value(value: vm),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<ShopViewModel>(
            create: (_) => ShopViewModel(playerVM)),
        ChangeNotifierProvider<TownViewModel>.value(value: townVM),
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: SettingsViewModel(_MockSettingsRepository()),
        ),
      ],
      child: MaterialApp(theme: theme, home: const TownScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_town_light_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('町タブ: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GameViewModel vm;
    late PlayerViewModel playerVM;
    late TownViewModel townVM;
    await tester.runAsync(() async {
      final vms = await _buildViewModels();
      vm = vms.$1;
      playerVM = vms.$2;
      townVM = vms.$3;
    });

    await _pump(
        tester, GameThemes.lightForJob(Job.adventurer), vm, playerVM, townVM);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('TOWN LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('町タブ: ダークは墨色へ退行していない（白系文字のまま）', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GameViewModel vm;
    late PlayerViewModel playerVM;
    late TownViewModel townVM;
    await tester.runAsync(() async {
      final vms = await _buildViewModels();
      vm = vms.$1;
      playerVM = vms.$2;
      townVM = vms.$3;
    });

    await _pump(
        tester, GameThemes.forJob(Job.adventurer), vm, playerVM, townVM);
    final scan = _scan(tester);
    // ignore: avoid_print
    print('TOWN DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30));
    // ライト用の墨（#2B2B2B / #4A4A4A / #5A5A5A / #6B6B6B）が漏れていないこと。
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A, 0xFF6B6B6B]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
