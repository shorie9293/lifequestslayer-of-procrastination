import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_app_keys.dart';
import 'package:rpg_todo/core/infrastructure/supabase_config.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/knowledge_quest_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/notification_settings_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/tutorial_reset_dialog.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('自動バックアップ失敗の可視化', () {
    testWidgets('statusStore 未注入なら従来の説明文（後方互換）', (tester) async {
      await tester.pumpWidget(wrap(const SettingsHubScreen()));
      await tester.pump();

      expect(find.byKey(AutoBackupKeys.entryFromSettings), findsOneWidget);
      expect(find.text('保存済みバックアップの閲覧・復元・共有'), findsOneWidget);
      expect(find.textContaining('自動バックアップに失敗しています'), findsNothing);
    });

    testWidgets('連続失敗が閾値未満なら通常の説明文', (tester) async {
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial.recordFailure(
          DateTime(2026, 10, 29, 7, 12),
          StateError('1回だけ失敗'),
        ),
      );
      await tester.pumpWidget(wrap(SettingsHubScreen(
        autoBackupStatusStore: statusStore,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('保存済みバックアップの閲覧・復元・共有'), findsOneWidget);
      expect(find.textContaining('失敗しています'), findsNothing);
    });

    testWidgets('連続失敗が閾値以上なら警告文言と警告アイコン', (tester) async {
      var status = AutoBackupStatus.initial;
      for (var i = 0; i < AutoBackupStatus.degradedThreshold; i++) {
        status = status.recordFailure(
          DateTime(2026, 10, 29, 7, 12).add(Duration(hours: i)),
          StateError('失敗$i'),
        );
      }
      final statusStore = InMemoryAutoBackupStatusStore(status);
      await tester.pumpWidget(wrap(SettingsHubScreen(
        autoBackupStatusStore: statusStore,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.textContaining('自動バックアップに失敗しています'),
        findsOneWidget,
      );
      expect(
        find.textContaining('${AutoBackupStatus.degradedThreshold}回連続'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('状態の読み出しが例外でも設定ハブは壊れない', (tester) async {
      await tester.pumpWidget(wrap(SettingsHubScreen(
        autoBackupStatusStore: _ThrowingStatusStore(),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(AutoBackupKeys.entryFromSettings), findsOneWidget);
      expect(find.text('保存済みバックアップの閲覧・復元・共有'), findsOneWidget);
    });
  });

  // ── 寄合所の設定メニューから移設した5項目（2026-11-28） ─────────────
  group('寄合所から移設した設定項目', () {
    setUpAll(() async {
      // 通知設定ダイアログは Hive の箱を開くため、テスト用パスを初期化する
      final dir = await Directory.systemTemp.createTemp('settings_hub_entries');
      Hive.init(dir.path);
    });

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('ヘルプ・通知・知識クエスト・導きの書のタイルが出る', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrap(const SettingsHubScreen()));
      await tester.pump();

      expect(find.byKey(AppKeys.settingsHelpTile), findsOneWidget);
      expect(find.byKey(AppKeys.settingsNotificationTile), findsOneWidget);
      expect(find.byKey(AppKeys.settingsKnowledgeQuestTile), findsOneWidget);
      expect(find.byKey(AppKeys.settingsTutorialResetTile), findsOneWidget);
      // 神託連携は Supabase 設定時のみ（未設定環境では導線を出さない）
      expect(
        find.byKey(AppKeys.settingsOracleLinkTile),
        SupabaseConfig.url.isNotEmpty ? findsOneWidget : findsNothing,
      );
    });

    testWidgets('ヘルプタイルでヘルプが開く', (tester) async {
      await tester.pumpWidget(wrap(const SettingsHubScreen()));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.settingsHelpTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HelpDialog), findsOneWidget);
    });

    testWidgets('導きの書リセットのタイルで確認ダイアログが開く', (tester) async {
      await tester.pumpWidget(wrap(const SettingsHubScreen()));
      await tester.pump();

      await tester.ensureVisible(find.byKey(AppKeys.settingsTutorialResetTile));
      await tester.tap(find.byKey(AppKeys.settingsTutorialResetTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(TutorialResetDialog), findsOneWidget);
    });

    testWidgets('知識クエストのタイルで詳細ダイアログが開く', (tester) async {
      await tester.pumpWidget(wrap(const SettingsHubScreen()));
      await tester.pump();

      await tester.ensureVisible(
          find.byKey(AppKeys.settingsKnowledgeQuestTile));
      await tester.tap(find.byKey(AppKeys.settingsKnowledgeQuestTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(KnowledgeQuestDialog), findsOneWidget);
    });

    testWidgets('通知のタイルで通知設定ダイアログが開く', (tester) async {
      await tester.pumpWidget(wrap(const SettingsHubScreen()));
      await tester.pump();

      await tester.ensureVisible(find.byKey(AppKeys.settingsNotificationTile));
      await tester.tap(find.byKey(AppKeys.settingsNotificationTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NotificationSettingsDialog), findsOneWidget);
    });
  });
}

class _ThrowingStatusStore implements AutoBackupStatusStore {
  @override
  Future<AutoBackupStatus?> read() async => throw StateError('読めない');

  @override
  Future<void> write(AutoBackupStatus status) async {}
}
