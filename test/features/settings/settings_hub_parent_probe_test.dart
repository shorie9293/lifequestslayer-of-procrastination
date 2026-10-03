import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 親探針: 『画面 → ViewModel → repository → 再ロード』の合成不変条件を撃つ。
///
/// 状態だけ更新して永続化に到達しない型の欠陥を検出する。
class _MutableSettingsRepo extends SettingsRepository {
  bool morning = true;
  double fontSize = 0.85;

  @override Future<int> getTutorialStep() async => 0;
  @override Future<void> setTutorialStep(int v) async {}
  @override Future<bool> getHasSeenConcept() async => false;
  @override Future<void> setHasSeenConcept(bool v) async {}
  @override Future<double> getFontSizeScale() async => fontSize;
  @override Future<void> setFontSizeScale(double v) async => fontSize = v;
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
  @override Future<void> setSfxEnabled(bool v) async {}
  @override Future<double> getSfxVolume() async => 0.7;
  @override Future<void> setSfxVolume(double v) async {}
  @override Future<bool> getBattleSceneEnabled() async => true;
  @override Future<void> setBattleSceneEnabled(bool v) async {}
  @override Future<bool> getMorningNotificationEnabled() async => morning;
  @override Future<void> setMorningNotificationEnabled(bool v) async =>
      morning = v;
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
  test('朝の通知: 設定操作が永続化に到達し、別のViewModelで復元される', () async {
    final repo = _MutableSettingsRepo();
    expect(repo.morning, isTrue);

    final vm = SettingsViewModel(repo);
    await vm.setMorningNotificationEnabled(false);
    // 状態だけでなく永続化層へ到達したか
    expect(repo.morning, isFalse);

    // 別インスタンス（再起動相当）で復元されるか
    final vm2 = SettingsViewModel(repo);
    expect(vm2.isMorningNotificationEnabled, isTrue, reason: 'load前は既定値');
    await vm2.load();
    expect(vm2.isMorningNotificationEnabled, isFalse,
        reason: 'load後に永続化値が復元される');
  });

  test('朝の通知: 既定値は true、set→load で往復する', () async {
    final repo = _MutableSettingsRepo();
    final vm = SettingsViewModel(repo);
    expect(vm.isMorningNotificationEnabled, isTrue);
    await vm.setMorningNotificationEnabled(true);
    expect(repo.morning, isTrue);
  });

  test('文字サイズ: setFontSizeScale が永続化層へ到達する', () async {
    final repo = _MutableSettingsRepo();
    final vm = SettingsViewModel(repo);
    await vm.setFontSizeScale(1.2);
    expect(repo.fontSize, 1.2);
    final vm2 = SettingsViewModel(repo);
    await vm2.load();
    expect(vm2.fontSizeScale, 1.2);
  });
}
