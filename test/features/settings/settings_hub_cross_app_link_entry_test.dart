// 設定ハブ → 連携状況 導線の試練。
//
// 「現世間の受け渡し」の最終送信／最終受信に到達できる入口が1つあること。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/settings/presentation/cross_app_link_status_screen.dart';
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
  late CrossAppLinkStatusRecorder recorder;

  setUp(() {
    vm = SettingsViewModel(_MockSettingsRepo());
    recorder = CrossAppLinkStatusRecorder(
      store: InMemoryCrossAppLinkStatusStore(),
      now: () => DateTime(2026, 11, 11, 9, 0),
    );
    CrossAppLinkStatusRecorder.reset(recorder);
  });

  tearDown(() => CrossAppLinkStatusRecorder.reset());

  Future<void> pumpHub(WidgetTester tester, Widget hub) async {
    tester.view.physicalSize = const Size(1080, 3600);
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

  testWidgets('設定ハブに連携状況タイルが1つ存在する', (tester) async {
    await pumpHub(tester, const SettingsHubScreen());

    expect(find.byKey(AppKeys.crossAppLinkStatusEntry), findsOneWidget);
    expect(find.text('連携状況（現世間の受け渡し）'), findsOneWidget);
  });

  testWidgets('タップで注入したビルダーが開く', (tester) async {
    var calls = 0;
    await pumpHub(
      tester,
      SettingsHubScreen(
        crossAppLinkStatusScreenBuilder: (_) {
          calls++;
          return const Scaffold(body: Center(child: Text('MARKER_LINK')));
        },
      ),
    );

    final entry = find.byKey(AppKeys.crossAppLinkStatusEntry);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('MARKER_LINK'), findsOneWidget);
  });

  testWidgets('既定なら実画面が開き「未記録」を出す', (tester) async {
    await pumpHub(tester, const SettingsHubScreen());

    final entry = find.byKey(AppKeys.crossAppLinkStatusEntry);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CrossAppLinkStatusScreen), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.sentKey), findsOneWidget);
    expect(find.text('未記録'), findsNWidgets(2));
  });
}
