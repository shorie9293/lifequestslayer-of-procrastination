// ライトテーマ実描画のコントラスト走査：戦闘画面（battle_screen）。
//
// 背景 #F7F3E8（和紙白）に対して、実描画された RenderParagraph の実効色／
// 実効背景を合成して比を出す。3.0:1 未満が 0 件であることを撃つ。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

class _PlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => Player();
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _TaskRepo implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

class _SettingsRepo extends SettingsRepository {
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
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => true;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => true;
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
  Future<bool> getBattleSceneEnabled() async => true;
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
      if (d is BoxDecoration) {
        if (d.color != null) {
          layers.add(d.color!);
        } else if (d.gradient case final LinearGradient g
            when g.colors.isNotEmpty) {
          // グラデーション面（戦闘演出の暗幕等）。上端色で近似する。
          layers.add(g.colors.first);
        }
      }
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

/// 他担当領域（guild の TaskCard / shared の PlayerStatusHeader）は並行作業中で
/// 本担当の対象外。ここでは数えず、別枠 [foreign] として報告する（黙って緑にしない）。
bool _inForeignSubtree(Element element) {
  var foreign = false;
  element.visitAncestorElements((ancestor) {
    final name = ancestor.widget.runtimeType.toString();
    if (name == 'TaskCard' || name == 'PlayerStatusHeader') {
      foreign = true;
      return false;
    }
    return true;
  });
  return foreign;
}

class _Scan {
  int measurable = 0;
  int violations = 0;
  int foreign = 0;
  double minRatio = 99;
  String worst = '';
  final List<String> details = [];

  @override
  String toString() {
    final base = 'measurable=$measurable violations=$violations '
        'foreign=$foreign min=${minRatio.toStringAsFixed(2)}:1 ($worst)';
    if (details.isEmpty) return base;
    return '$base\n  ${details.join('\n  ')}';
  }
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
    if (_inForeignSubtree(element)) {
      scan.foreign++;
      continue;
    }
    final bg = _effectiveBackground(element, scaffold);
    final raw = ro.text.style?.color ?? fallback;
    final eff = Color.alphaBlend(raw, bg);
    final ratio = _contrast(eff, bg);
    scan.measurable++;
    if (ratio < scan.minRatio) {
      scan.minRatio = ratio;
      scan.worst = '"$plain"';
    }
    if (ratio < 3.0 && seen.add(plain)) {
      scan.violations++;
      scan.details.add(
          '${ratio.toStringAsFixed(2)}:1 "$plain" fg=#${raw.toARGB32().toRadixString(16).padLeft(8, '0')} bg=#${bg.toARGB32().toRadixString(16).padLeft(8, '0')}');
    }
  }
  return scan;
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

  testWidgets('戦闘画面: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playerVM = PlayerViewModel(_PlayerRepo());
    final taskVM = TaskViewModel(_TaskRepo(), playerVM);
    final settingsVM = SettingsViewModel(_SettingsRepo());

    await tester.runAsync(() async {
      await playerVM.load();
      playerVM.player.jobLevels[playerVM.player.currentJob] = 5;
      taskVM.addTask('古文書の解読', rank: QuestRank.B, targetTimeMinutes: 30);
      taskVM.addTask('剣術の稽古', rank: QuestRank.A, targetTimeMinutes: 45);
      taskVM.addTask('薬草集め', rank: QuestRank.B, targetTimeMinutes: 15);
      for (final t in List<Task>.from(taskVM.tasks)) {
        taskVM.acceptTask(t.id);
      }
      await settingsVM.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ChangeNotifierProvider<GameViewModel>.value(
            value: GameViewModel(
              playerVM: playerVM,
              taskVM: taskVM,
              settingsVM: settingsVM,
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: GameThemes.lightForJob(Job.adventurer),
          home: BattleScreen(
            battleRecordRepository: InMemoryBattleRecordRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scan = _scan(tester);
    // ignore: avoid_print
    print('LIGHT(list) $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
    // 一覧フェーズは battle 所有の文字が少ない（TaskCard/PlayerStatusHeader は
    // 他担当領域で foreign 扱い）。母数は戦術選択フェーズと合算して判定する。
    expect(scan.measurable, greaterThanOrEqualTo(3),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.foreign, greaterThan(0),
        reason: 'foreign 除外が効いていない＝走査自体が壊れている疑い: $scan');
  });

  testWidgets('戦闘画面（戦術選択フェーズ）: ライト実描画で 3.0:1 未満が 0 件',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playerVM = PlayerViewModel(_PlayerRepo());
    final taskVM = TaskViewModel(_TaskRepo(), playerVM);
    final settingsVM = SettingsViewModel(_SettingsRepo());

    await tester.runAsync(() async {
      await playerVM.load();
      playerVM.player.jobLevels[playerVM.player.currentJob] = 5;
      taskVM.addTask('古文書の解読', rank: QuestRank.B, targetTimeMinutes: 30);
      for (final t in List<Task>.from(taskVM.tasks)) {
        taskVM.acceptTask(t.id);
      }
      await settingsVM.load();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ChangeNotifierProvider<GameViewModel>.value(
            value: GameViewModel(
              playerVM: playerVM,
              taskVM: taskVM,
              settingsVM: settingsVM,
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: GameThemes.lightForJob(Job.adventurer),
          home: BattleScreen(
            battleRecordRepository: InMemoryBattleRecordRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 一覧→展開→戦術選択フェーズ（暗幕の戦闘演出）
    await tester.tap(find.text('[B] 古文書の解読'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('討つ！'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scan = _scan(tester);
    // ignore: avoid_print
    print('LIGHT(combat) $scan');
    expect(scan.measurable, greaterThanOrEqualTo(10),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });
}
