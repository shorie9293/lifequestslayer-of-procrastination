// 設定ハブ ⇄ アカウント削除 導線の試練（後方互換の担保を含む）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_app_keys.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

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
  late SettingsViewModel vm;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    vm = SettingsViewModel(_MockSettingsRepo());
  });

  Future<void> pumpHub(WidgetTester tester, Widget hub) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsViewModel>.value(
        value: vm,
        child: MaterialApp(home: hub),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('ビルダー未注入ならアカウント削除タイルは出ない（後方互換）',
      (tester) async {
    await pumpHub(tester, const SettingsHubScreen());

    expect(
      find.byKey(AccountDeletionAppKeys.entryFromSettings),
      findsNothing,
    );
    expect(find.text('アカウント削除'), findsNothing);
  });

  testWidgets('ビルダー注入でタイルが出て、タップで画面が開く', (tester) async {
    var builderCalls = 0;
    await pumpHub(
      tester,
      SettingsHubScreen(
        accountDeletionScreenBuilder: (_) {
          builderCalls++;
          return const Scaffold(body: Center(child: Text('MARKER_DELETE')));
        },
      ),
    );

    expect(
      find.byKey(AccountDeletionAppKeys.entryFromSettings),
      findsOneWidget,
    );

    await tester.tap(find.byKey(AccountDeletionAppKeys.entryFromSettings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(builderCalls, 1);
    expect(find.text('MARKER_DELETE'), findsOneWidget);
  });
}
