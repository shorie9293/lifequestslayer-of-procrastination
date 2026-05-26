import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

class _MockSettingsRepo extends SettingsRepository {
  @override Future<int> getTutorialStep() async => 0;
  @override Future<bool> getHasSeenConcept() async => false;
  @override Future<double> getFontSizeScale() async => 0.85;
  @override Future<bool> getKnowledgeQuestEnabled() async => true;
  @override Future<bool> getTutorialSkipped() async => false;
  @override Future<bool> getTutorialChoiceMade() async => false;
  @override Future<bool> getJobTutorialCompleted() async => false;
  @override Future<bool> getDebugModeEnabled() async => false;
  @override Future<void> setFontSizeScale(double v) async {}
  @override Future<DateTime?> getFatiguePopupDate() async => null;
  @override Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override Future<void> setTutorialStep(int v) async {}
  @override Future<void> setHasSeenConcept(bool v) async {}
  @override Future<void> setTutorialSkipped(bool v) async {}
  @override Future<void> setTutorialChoiceMade(bool v) async {}
  @override Future<void> setJobTutorialCompleted(bool v) async {}
  @override Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override Future<void> deleteFatiguePopupDate() async {}
  @override Future<void> resetTutorial() async {}
  @override Future<void> setDebugModeEnabled(bool v) async {}
}

void main() {
  late SettingsViewModel vm;
  setUp(() {
    vm = SettingsViewModel(_MockSettingsRepo());
  });

  test('debug mode enabled with correct password', () {
    final result = vm.tryEnableDebugMode('11111111');
    expect(result, true);
    expect(vm.isDebugMode, true);
  });

  test('debug mode not enabled with wrong password', () {
    final result = vm.tryEnableDebugMode('wrong');
    expect(result, false);
    expect(vm.isDebugMode, false);
  });

  test('knowledgeQuest toggle', () async {
    await vm.setKnowledgeQuestEnabled(false);
    expect(vm.isKnowledgeQuestEnabled, false);
  });
}
