// ライトテーマ実描画のコントラスト走査（メイン画面の常設オーバーレイとダイアログ）。
//
// MainScreen が自前で描く直書き色（Colors.grey / Colors.amber[700]+白 /
// Colors.white24 等）を GamePalette トークンへ寄せた結果、
// - ライト実描画で 3.0:1 未満が 0 件（常設要素・オフライン復帰ダイアログ）
// - ダークでは従来の白系文字が保たれていること
// を実描画から撃つ。
//
// 闇地（スキップボタンの黒帯・オフラインバナーの黒・報酬演出の暗幕）は
// 置換対象外なので、ここでも違反として数えない＝背景合成で自然に高比になる。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/reduce_motion_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/screens/main_screen.dart';

// ── DI モック ────────────────────────────────────────────

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => Player(jobLevels: {Job.adventurer: 5});
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
  Future<double> getFontSizeScale() async => 1.0;
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
  // チュートリアルは完了済みにする（オーバーレイで走査対象が濁らないように）。
  @override
  Future<int> getTutorialStep() async => 3;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => true;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool value) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => true;
  @override
  Future<void> setTutorialChoiceMade(bool value) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => true;
  @override
  Future<void> setJobTutorialCompleted(bool value) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => false;
  @override
  Future<double> getSfxVolume() async => 0.0;
  @override
  Future<void> setSfxVolume(double volume) async {}
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => false;
  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

class _Audio extends BattleAudioService {
  @override
  bool get sfxEnabled => false;
  @override
  void setSfxEnabled(bool enabled) {}
  @override
  Future<void> playVictory() async {}
  @override
  Future<void> playDefeat() async {}
}

class _StubReduceMotionRepository implements ReduceMotionRepository {
  @override
  Future<ReduceMotionSetting?> load() async => null;
  @override
  Future<void> save(ReduceMotionSetting setting) async {}
}

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

  final playerVM = PlayerViewModel(_MockPlayerRepository());
  final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(_MockSettingsRepository());
  final shopVM = ShopViewModel(playerVM);
  final townVM = TownViewModel();
  final gameVM = GameViewModel(
    playerVM: playerVM,
    taskVM: taskVM,
    shopVM: shopVM,
    settingsVM: settingsVM,
    autoLoad: false,
  );
  await tester.runAsync(() async {
    await playerVM.load();
    await taskVM.load();
    await settingsVM.load();
    townVM.initialize();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
        ChangeNotifierProvider<ShopViewModel>.value(value: shopVM),
        ChangeNotifierProvider<TownViewModel>.value(value: townVM),
        ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
        ChangeNotifierProvider<ReduceMotionViewModel>(
            create: (_) =>
                ReduceMotionViewModel(_StubReduceMotionRepository())),
      ],
      // オフライン状態で起動する＝オフラインバナー（常設）を描画させる。
      child: MaterialApp(
        theme: theme,
        home: MainScreen(offline: true, onExitOffline: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    if (getIt.isRegistered<BattleViewModel>()) {
      getIt.unregister<BattleViewModel>();
    }
    if (getIt.isRegistered<BattleAudioService>()) {
      getIt.unregister<BattleAudioService>();
    }
    getIt.registerLazySingleton<BattleViewModel>(() => BattleViewModel());
    getIt.registerLazySingleton<BattleAudioService>(() => _Audio());
  });

  testWidgets('メイン画面: ライトの常設要素で 3.0:1 未満が 0 件', (tester) async {
    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('MAIN LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(20),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('メイン画面: ライトのオフライン復帰ダイアログで 3.0:1 未満が 0 件', (tester) async {
    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    await tester.tap(find.text('オフライン'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('キャンセル'), findsOneWidget, reason: 'ダイアログが開いていない＝走査対象が空振り');
    expect(find.text('戻る'), findsOneWidget);

    final scan = _scan(tester);
    // ignore: avoid_print
    print('MAIN LIGHT DIALOG $scan');
    expect(scan.measurable, greaterThanOrEqualTo(30),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ダイアログに読めない文字: $scan');
  });

  testWidgets('メイン画面: ダークは白系文字のまま（墨色へ退行していない）', (tester) async {
    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('MAIN DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(20));
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A, 0xFF6B6B6B]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
