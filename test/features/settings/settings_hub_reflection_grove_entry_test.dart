// 設定ハブ → 振り返りの杜 導線の試練。
// 到達不能だった ReflectionGroveScreen が設定ハブから1本だけ接続されたことを検証する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';

class _MockSettingsRepo extends SettingsRepository {
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int v) async {}
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<void> setHasSeenConcept(bool v) async {}
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<void> setFontSizeScale(double v) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool v) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<void> setTutorialChoiceMade(bool v) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setJobTutorialCompleted(bool v) async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => true;
  @override
  Future<void> setSfxEnabled(bool v) async {}
  @override
  Future<double> getSfxVolume() async => 0.7;
  @override
  Future<void> setSfxVolume(double v) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => true;
  @override
  Future<void> setBattleSceneEnabled(bool v) async {}
  @override
  Future<bool> getMorningNotificationEnabled() async => true;
  @override
  Future<void> setMorningNotificationEnabled(bool v) async {}
  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.dark;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

void main() {
  late Directory tempDir;
  late _MockSettingsRepo repo;
  late SettingsViewModel vm;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_reflection_grove_entry_');
    Hive.init(tempDir.path);
    repo = _MockSettingsRepo();
    vm = SettingsViewModel(repo);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget wrap(Widget child) => ChangeNotifierProvider<SettingsViewModel>.value(
        value: vm,
        child: MaterialApp(home: child),
      );

  Future<void> pumpHub(WidgetTester tester, Widget hub) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(wrap(hub));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('設定ハブに振り返りの杜タイルが1つ存在する', (tester) async {
    await pumpHub(tester, const SettingsHubScreen());

    expect(find.byKey(AppKeys.reflectionGroveEntry), findsOneWidget);
    expect(find.text('振り返りの杜'), findsOneWidget);
  });

  testWidgets('注入した reflectionGroveScreenBuilder がタップで呼ばれ表示される',
      (tester) async {
    var builderCalls = 0;
    await pumpHub(
      tester,
      SettingsHubScreen(
        reflectionGroveScreenBuilder: (_) {
          builderCalls++;
          return const Scaffold(
            body: Center(child: Text('MARKER_GROVE')),
          );
        },
      ),
    );

    final entry = find.byKey(AppKeys.reflectionGroveEntry);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(builderCalls, 1);
    expect(find.text('MARKER_GROVE'), findsOneWidget);
    // 実画面は生成されない（Hive を触らない）
    expect(find.byType(ReflectionGroveScreen), findsNothing);
  });

  testWidgets('注入なし（既定）ならタップで実 ReflectionGroveScreen が開く',
      (tester) async {
    // 実 Hive の openBox は FakeAsync ゾーンで完了しないため runAsync で開口する
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
    });

    await pumpHub(tester, const SettingsHubScreen());

    final entry = find.byKey(AppKeys.reflectionGroveEntry);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pump();
    await tester.pump();

    // _load() の Hive box 読込 → setState を実時間で完了させる
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();

    expect(find.byType(ReflectionGroveScreen), findsOneWidget);
    expect(find.byKey(AppKeys.reflectionGroveScreen), findsOneWidget);
  });
}
