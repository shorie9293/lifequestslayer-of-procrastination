import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

class _MockSettingsRepo extends SettingsRepository {
  bool lastMorning = true;
  int morningCalls = 0;
  double lastFontSize = -1;
  int fontSizeCalls = 0;
  bool lastSfxEnabled = true;
  int sfxCalls = 0;

  @override Future<int> getTutorialStep() async => 0;
  @override Future<void> setTutorialStep(int v) async {}
  @override Future<bool> getHasSeenConcept() async => false;
  @override Future<void> setHasSeenConcept(bool v) async {}
  @override Future<double> getFontSizeScale() async => 0.85;
  @override Future<void> setFontSizeScale(double v) async {
    lastFontSize = v;
    fontSizeCalls++;
  }
  @override Future<bool> getKnowledgeQuestEnabled() async => true;
  @override Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override Future<bool> getTutorialSkipped() async => false;
  @override Future<void> setTutorialSkipped(bool v) async {}
  @override Future<bool> getTutorialChoiceMade() async => false;
  @override Future<void> setTutorialChoiceMade(bool v) async {}
  @override Future<bool> getJobTutorialCompleted() async => false;
  @override Future<void> setJobTutorialCompleted(bool v) async {}
  @override Future<bool> getDebugModeEnabled() async => false;
  @override Future<void> setDebugModeEnabled(bool v) async {}
  @override Future<bool> getSfxEnabled() async => true;
  @override Future<void> setSfxEnabled(bool v) async {
    lastSfxEnabled = v;
    sfxCalls++;
  }
  @override Future<double> getSfxVolume() async => 0.7;
  @override Future<void> setSfxVolume(double v) async {}
  @override Future<bool> getBattleSceneEnabled() async => true;
  @override Future<void> setBattleSceneEnabled(bool v) async {}
  @override Future<bool> getMorningNotificationEnabled() async => true;
  @override Future<void> setMorningNotificationEnabled(bool v) async {
    lastMorning = v;
    morningCalls++;
  }
  @override Future<ThemeMode> getThemeMode() async => ThemeMode.dark;
  @override Future<void> setThemeMode(ThemeMode mode) async {}
  @override Future<DateTime?> getFatiguePopupDate() async => null;
  @override Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override Future<void> deleteFatiguePopupDate() async {}
  @override Future<void> resetTutorial() async {}
  @override Future<DateTime?> getLastBackupTime() async => null;
  @override Future<void> setLastBackupTime(DateTime time) async {}
}

void main() {
  late _MockSettingsRepo repo;
  late SettingsViewModel vm;

  setUp(() {
    repo = _MockSettingsRepo();
    vm = SettingsViewModel(repo);
  });

  Widget wrap(Widget child) => ChangeNotifierProvider<SettingsViewModel>.value(
        value: vm,
        child: MaterialApp(home: child),
      );

  testWidgets('全セクションのkeyが表示される', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(wrap(const SettingsHubScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
    expect(find.byKey(AppKeys.settingsFontSizeSlider), findsOneWidget);
    expect(find.byKey(AppKeys.settingsFontSizeLabel), findsOneWidget);
    expect(find.byKey(AppKeys.settingsSfxEnabledSwitch), findsOneWidget);
    expect(find.byKey(AppKeys.settingsMorningNotificationSwitch), findsOneWidget);
    expect(find.byKey(AppKeys.settingsReminderTile), findsOneWidget);
    expect(find.byKey(AppKeys.settingsKnowledgeQuestSwitch), findsOneWidget);
    expect(find.byKey(AppKeys.settingsBattleSceneSwitch), findsOneWidget);
  });

  testWidgets('朝の通知スイッチでrepo.setMorningNotificationEnabledが呼ばれる', (tester) async {
    await tester.pumpWidget(wrap(const SettingsHubScreen()));
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.settingsMorningNotificationSwitch));
    await tester.pump();

    expect(repo.morningCalls, 1);
    expect(repo.lastMorning, isFalse);
    expect(vm.isMorningNotificationEnabled, isFalse);
  });

  testWidgets('フォントサイズSliderでsetFontSizeScaleに到達する', (tester) async {
    await tester.pumpWidget(wrap(const SettingsHubScreen()));
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.settingsFontSizeSlider),
        warnIfMissed: false);
    await tester.pump();

    expect(repo.fontSizeCalls, greaterThanOrEqualTo(1));
    expect(repo.lastFontSize, inInclusiveRange(0.7, 1.2));
  });

  testWidgets('リマインダータイルでbuilderがpushされる', (tester) async {
    await tester.pumpWidget(wrap(SettingsHubScreen(
      reminderScreenBuilder: (_) => const Scaffold(
        key: Key('dummy_reminder'), body: Text('勤行リマインダー')),
    )));
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.settingsReminderTile));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('dummy_reminder')), findsOneWidget);
  });
}
