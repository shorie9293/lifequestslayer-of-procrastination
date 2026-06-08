import 'package:flutter/material.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/tutorial_service.dart';

/// 設定関連の状態を管理するViewModel
class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final TutorialService _tutorial;

  int _tutorialStep = 0;
  bool _sawConcept = false;
  bool _tutSkipped = false;
  bool _tutChosen = false;
  bool _jobTutorialCompleted = false;
  bool _showJobTutorial = false;
  double _fontSize = 0.85;
  bool _kqEnabled = true;
  bool _debugMode = false;

  SettingsViewModel(this._settingsRepository)
      : _tutorial = TutorialService(_settingsRepository);

  int get tutorialStep => _tutorialStep;
  bool get hasSeenConcept => _sawConcept;
  bool get tutorialSkipped => _tutSkipped;
  bool get tutorialChoiceMade => _tutChosen;
  bool get showJobTutorial => _showJobTutorial;
  bool get jobTutorialCompleted => _jobTutorialCompleted;
  double get fontSizeScale => _fontSize;
  bool get isKnowledgeQuestEnabled => _kqEnabled;
  bool get isDebugMode => _debugMode;

  // ── 設定操作 ──
  Future<void> setKnowledgeQuestEnabled(bool v) async {
    _kqEnabled = v;
    await _settingsRepository.setKnowledgeQuestEnabled(v);
    notifyListeners();
  }

  Future<void> setFontSizeScale(double v) async {
    _fontSize = v;
    await _settingsRepository.setFontSizeScale(v);
    notifyListeners();
  }

  // ── デバッグモード ──
  bool tryEnableDebugMode(String password) {
    if (password == '11111111') {
      _debugMode = true;
      _settingsRepository.setDebugModeEnabled(true);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── チュートリアル ──
  Future<void> completeTutorialStep(int step) async {
    final n = await _tutorial.advanceStep(_tutorialStep, step);
    if (n != null) {
      _tutorialStep = n;
      notifyListeners();
    }
  }

  Future<void> markConceptAsSeen() async {
    if (await _tutorial.markSeen(_sawConcept)) {
      _sawConcept = true;
      notifyListeners();
    }
  }

  Future<void> markTutorialChoiceMade() async {
    await _tutorial.persistChoiceMade();
    _tutChosen = true;
    notifyListeners();
  }

  Future<void> skipTutorial() async {
    await _tutorial.persistSkip();
    _tutorialStep = 3;
    _tutSkipped = true;
    _sawConcept = true;
    _tutChosen = true;
    notifyListeners();
  }

  Future<void> resetTutorial() async {
    await _tutorial.resetAll();
    _tutorialStep = 0;
    _sawConcept = false;
    _tutSkipped = false;
    _tutChosen = false;
    notifyListeners();
  }

  Future<void> markJobTutorialSeen() async {
    if (await _tutorial.markJobTutorialSeen(_jobTutorialCompleted)) {
      _jobTutorialCompleted = true;
      _showJobTutorial = false;
      notifyListeners();
    }
  }

  void dismissJobTutorial() {
    _showJobTutorial = false;
    notifyListeners();
  }

  void setShowJobTutorial(bool v) {
    _showJobTutorial = v;
    notifyListeners();
  }

  // ── データロード ──
  Future<void> load() async {
    await _load<int>(_settingsRepository.getTutorialStep, (v) => _tutorialStep = v, label: 'tutorialStep');
    await _load<bool>(_settingsRepository.getHasSeenConcept, (v) => _sawConcept = v, label: 'sawConcept');
    await _load<double>(_settingsRepository.getFontSizeScale, (v) => _fontSize = v, label: 'fontSizeScale');
    await _load<bool>(_settingsRepository.getKnowledgeQuestEnabled, (v) => _kqEnabled = v, label: 'knowledgeQuest');
    await _load<bool>(_settingsRepository.getTutorialSkipped, (v) => _tutSkipped = v, label: 'tutorialSkipped');
    await _load<bool>(_settingsRepository.getTutorialChoiceMade, (v) => _tutChosen = v, label: 'tutorialChoiceMade');
    await _load<bool>(_settingsRepository.getJobTutorialCompleted, (v) => _jobTutorialCompleted = v, label: 'jobTutorialCompleted');
    await _load<bool>(_settingsRepository.getDebugModeEnabled, (v) => _debugMode = v, label: 'debugMode');

    if (await _tutorial.repairSeenConcept(_tutorialStep, _sawConcept)) {
      _sawConcept = true;
    }
    notifyListeners();
  }

  Future<void> _load<T>(Future<T> Function() loader, void Function(T) setter, {String label = ''}) async {
    try {
      setter(await loader());
    } catch (e, st) {
      if (label.isNotEmpty) debugPrint('[SettingsVM] $label load error: $e\n$st');
    }
  }
}
