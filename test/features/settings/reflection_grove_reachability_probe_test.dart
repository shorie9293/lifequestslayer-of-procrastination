// 親探針: 振り返りの杜への導線接続が「三点同時開通」をもたらしたことの合成検証。
// #162 の本質は「杜が開けること」ではなく「杜の中にしか無い #61 内省バッジ図鑑と
// #102 週次グリフォン報告が初めてユーザーに届くこと」である。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_badge_collection_screen.dart';
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
  late SettingsViewModel vm;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_grove_probe_');
    Hive.init(tempDir.path);
    vm = SettingsViewModel(_MockSettingsRepo());
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

  /// 設定ハブから「振り返りの杜」タイルをタップし、杜の読込完了まで進める。
  Future<void> openGrove(WidgetTester tester) async {
    await tester.runAsync(() async {
      final repo = ReflectionRepository();
      await repo.save(
        Reflection(
          id: 'r1',
          taskId: 't1',
          date: DateTime.now(),
          content: '難しかったが次は改善する',
          selfDifficulty: 3,
          aiDifficulty: QuestRank.A,
        ),
      );
    });
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const SettingsHubScreen()));
    await tester.pump();
    await tester.pump();

    final entry = find.byKey(AppKeys.reflectionGroveEntry);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    // ルート遷移アニメーションを完了させる（途中で測るとAppBarが画面外になる）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('探針1: 設定ハブ→杜→内省バッジ図鑑 まで実タップで到達する（#61 が初めて届く）',
      (tester) async {
    await openGrove(tester);

    expect(find.byKey(AppKeys.reflectionGroveScreen), findsOneWidget);
    expect(find.byType(ReflectionGroveScreen), findsOneWidget);

    // 杜の AppBar にしか存在しない内省バッジへの導線を実際に押す
    final badgeButton = find.byKey(AppKeys.reflectionBadgeCollectionButton);
    expect(badgeButton, findsOneWidget);
    await tester.tap(badgeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ReflectionBadgeCollectionScreen), findsOneWidget);
    expect(find.byKey(AppKeys.reflectionBadgeCollectionScreen), findsOneWidget);
  });

  testWidgets('探針2: 杜の中で週次グリフォン報告セクションが実際に描画される（#102 が初めて届く）',
      (tester) async {
    await openGrove(tester);

    expect(find.byKey(AppKeys.gryphonReportSection), findsOneWidget);
  });

  testWidgets('探針3: 導線は1本だけ・既存タイルを押し出さない', (tester) async {
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
    });
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const SettingsHubScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(AppKeys.reflectionGroveEntry), findsOneWidget);
    // 追加は末尾のみ＝既存導線は健在（押し出しなし）
    expect(find.byKey(AboutAppKeys.entryFromSettings), findsOneWidget);
    expect(find.byKey(AppKeys.settingsReminderTile), findsOneWidget);
  });
}
