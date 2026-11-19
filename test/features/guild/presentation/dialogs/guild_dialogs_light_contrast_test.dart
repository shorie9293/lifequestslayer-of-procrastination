// ライトテーマ実描画のコントラスト走査（寄合所の各ダイアログ）。
//
// 直書き色（Colors.amber[200] / Colors.grey[400] / 琥珀地+白文字のボタン等）を
// GamePalette トークンへ寄せた結果、和紙白の地で読めない文字が 0 件であることを
// 実描画から撃つ。走査ハーネスは guild_screen_light_contrast_test.dart と同方式
// （各試練ファイルへ複製する方針のため、ここにも写している）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/bulk_create_task_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/create_task_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/tutorial_reset_dialog.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

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

// ── 走査ハーネス（guild_screen_light_contrast_test.dart と同方式） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _darkestOf(List<Color> colors) => colors
    .reduce((a, b) => a.computeLuminance() <= b.computeLuminance() ? a : b);

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
      // Chip の背景は _RenderChip.paint が描くため backgroundColor を拾う。
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

Future<void> _pumpDialog(
  WidgetTester tester,
  ThemeData theme,
  Widget dialog,
) async {
  final playerVM = PlayerViewModel(_MockPlayerRepository());
  final taskVM = TaskViewModel(_MockTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(_MockSettingsRepository());
  final gameVM = GameViewModel(
    pr: _MockPlayerRepository(),
    tr: _MockTaskRepository(),
    sr: _MockSettingsRepository(),
  );
  await tester.runAsync(() async {
    await playerVM.load();
    while (!gameVM.isLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
        ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              // 走査対象をダイアログ内に限定するため、ホストのボタンは墨色で固定
              // （ライトの既定 ElevatedButton は前景が primary=金で 1.95:1 になる
              //  既知のテーマ側課題。ここでは踏まない）。
              style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => dialog,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() {
    // ダイアログは高さが伸びるので縦長に。
  });

  testWidgets('クエスト作成: ライトで 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
        tester, GameThemes.lightForJob(Job.adventurer), const CreateTaskDialog());
    final scan = _scan(tester);
    // ignore: avoid_print
    print('CREATE TASK DIALOG LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(12),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('クエスト一括登録: ライトで 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(tester, GameThemes.lightForJob(Job.adventurer),
        const BulkCreateTaskDialog());
    final scan = _scan(tester);
    // ignore: avoid_print
    print('BULK CREATE DIALOG LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(8),
        reason: '走査母数が少なすぎる: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('導きの書リセット: ライトで 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(tester, GameThemes.lightForJob(Job.adventurer),
        const TutorialResetDialog());
    final scan = _scan(tester);
    // ignore: avoid_print
    print('TUTORIAL RESET DIALOG LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(5),
        reason: '走査母数が少なすぎる: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('クエスト作成: ダークは墨色へ退行していない', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
        tester, GameThemes.forJob(Job.adventurer), const CreateTaskDialog());
    final scan = _scan(tester);
    // ignore: avoid_print
    print('CREATE TASK DIALOG DARK $scan');
    expect(scan.measurable, greaterThanOrEqualTo(12));
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
