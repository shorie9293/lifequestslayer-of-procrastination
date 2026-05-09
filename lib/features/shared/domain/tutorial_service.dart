import 'package:rpg_todo/features/shared/data/settings_repository.dart';

/// Manages tutorial state persistence.
///
/// Methods persist to [SettingsRepository] and return new values
/// for the caller to apply. This keeps state mutation in the ViewModel
/// while the service handles the persistence contract.
class TutorialService {
  final SettingsRepository _settingsRepository;

  TutorialService(this._settingsRepository);

  /// Advances tutorial step if [currentStep] matches [targetStep].
  /// Returns the new step, or null if no change.
  Future<int?> advanceStep(int currentStep, int targetStep) async {
    if (currentStep != targetStep) return null;
    final newStep = currentStep + 1;
    await _settingsRepository.setTutorialStep(newStep);
    return newStep;
  }

  /// Marks concept as seen. Returns true if state was actually changed.
  Future<bool> markSeen(bool current) async {
    if (current) return false;
    await _settingsRepository.setHasSeenConcept(true);
    return true;
  }

  /// Persists all skip-related settings (step=3, skipped, seen, choiceMade).
  Future<void> persistSkip() async {
    await _settingsRepository.setTutorialStep(3);
    await _settingsRepository.setTutorialSkipped(true);
    await _settingsRepository.setHasSeenConcept(true);
    await _settingsRepository.setTutorialChoiceMade(true);
  }

  /// Persists tutorial choice as made.
  Future<void> persistChoiceMade() async {
    await _settingsRepository.setTutorialChoiceMade(true);
  }

  /// Resets all tutorial state to defaults.
  Future<void> resetAll() async {
    await _settingsRepository.resetTutorial();
  }

  /// Marks job tutorial as seen. Returns true if state was actually changed.
  Future<bool> markJobTutorialSeen(bool current) async {
    if (current) return false;
    await _settingsRepository.setJobTutorialCompleted(true);
    return true;
  }

  /// If step > 2 and [hasSeen] is false, persist the fix and return true.
  Future<bool> repairSeenConcept(int step, bool hasSeen) async {
    if (step > 2 && !hasSeen) {
      await _settingsRepository.setHasSeenConcept(true);
      return true;
    }
    return false;
  }
}
