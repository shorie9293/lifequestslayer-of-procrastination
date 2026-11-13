import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/settings_write_result.dart';
import 'package:rpg_todo/features/shared/domain/tutorial_service.dart';
import 'package:injectable/injectable.dart';

/// 設定関連の状態を管理するViewModel
@lazySingleton
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
  bool _sfxEnabled = true;
  double _sfxVolume = SfxVolumeSetting.defaultValue;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _battleSceneEnabled = true;
  DateTime? _lastBackupTime;
  bool _morningNotificationEnabled = true;
  String? _lastWriteError;

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
  bool get isSfxEnabled => _sfxEnabled;
  double get sfxVolume => _sfxVolume;
  ThemeMode get themeMode => _themeMode;
  bool get isBattleSceneEnabled => _battleSceneEnabled;
  bool get isMorningNotificationEnabled => _morningNotificationEnabled;
  DateTime? get lastBackupTime => _lastBackupTime;

  // ── 設定操作 ──

  /// 直近の保存失敗理由（成功すると null に戻る）。
  ///
  /// 画面はこの値を見て「保存できませんでした」を出せる。メモリ先行更新を
  /// 廃したため、失敗時に getter が新しい値を返すことはない。
  String? get lastWriteError => _lastWriteError;

  /// 失敗理由を消費済みにする（画面が1度だけ通知した後で呼ぶ）。
  ///
  /// 通知はしないため、聴取器のコールバックから呼んでも再入しない。
  void clearWriteError() {
    _lastWriteError = null;
  }

  /// 保存 → 成功時のみメモリ確定 → 通知、の順で適用する。
  ///
  /// 失敗時はメモリを旧値のまま残し、[lastWriteError] に理由を載せる。
  Future<void> _commitWrite(
    Future<SettingsWriteResult> Function() write,
    void Function() apply,
  ) async {
    final result = await write();
    if (result.ok) {
      apply();
      _lastWriteError = null;
    } else {
      _lastWriteError = result.errorMessage;
    }
    notifyListeners();
  }

  Future<void> setKnowledgeQuestEnabled(bool v) => _commitWrite(
        () => _settingsRepository.writeKnowledgeQuestEnabled(v),
        () => _kqEnabled = v,
      );

  Future<void> setSfxEnabled(bool v) => _commitWrite(
        () => _settingsRepository.writeSfxEnabled(v),
        () => _sfxEnabled = v,
      );

  /// 効果音の音量を設定する（改善提案#67）。0.0〜1.0 にクランプして永続化する。
  Future<void> setSfxVolume(double v) {
    final next = SfxVolumeSetting(v).value;
    return _commitWrite(
      () => _settingsRepository.writeSfxVolume(next),
      () => _sfxVolume = next,
    );
  }

  Future<void> setBattleSceneEnabled(bool v) => _commitWrite(
        () => _settingsRepository.writeBattleSceneEnabled(v),
        () => _battleSceneEnabled = v,
      );

  Future<void> setFontSizeScale(double v) => _commitWrite(
        () => _settingsRepository.writeFontSizeScale(v),
        () => _fontSize = v,
      );

  Future<void> setThemeMode(ThemeMode mode) => _commitWrite(
        () => _settingsRepository.writeThemeMode(mode),
        () => _themeMode = mode,
      );

  Future<void> setMorningNotificationEnabled(bool v) => _commitWrite(
        () => _settingsRepository.writeMorningNotificationEnabled(v),
        () => _morningNotificationEnabled = v,
      );

  // ── デバッグモード ──
  bool tryEnableDebugMode(String password) {
    if (password == '11111111') {
      _debugMode = true;
      notifyListeners();
      unawaited(_persistDebugMode());
      return true;
    }
    return false;
  }

  /// デバッグモードの永続化。同期 API を保つため投げっぱなしにせず、
  /// 失敗は [lastWriteError] に載せる（未処理例外を zone へ漏らさない）。
  Future<void> _persistDebugMode() async {
    final result = await _settingsRepository.writeDebugModeEnabled(true);
    _lastWriteError = result.ok ? null : result.errorMessage;
    notifyListeners();
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

  // ── バックアップ（道標§五#17: 最終バックアップ日時） ──
  Future<void> recordBackupNow() async {
    final now = DateTime.now();
    final result = await _settingsRepository.writeLastBackupTime(now);
    // 例外扱い（この1点のみ）: バックアップ本体は既に生成済みなので、
    // 日時の記録に失敗してもメモリ上の最終時刻は前進させる。失敗の事実は
    // lastWriteError で可視化する（次回起動時に戻るのはバックアップ自体が
    // 存在するため実害が小さい）。
    _lastBackupTime = now;
    _lastWriteError = result.ok ? null : result.errorMessage;
    notifyListeners();
  }

  void setShowJobTutorial(bool v) {
    _showJobTutorial = v;
    notifyListeners();
  }

  // ── データロード ──
  Future<void> load() async {
    await _load<int>(
        _settingsRepository.getTutorialStep, (v) => _tutorialStep = v,
        label: 'tutorialStep');
    await _load<bool>(
        _settingsRepository.getHasSeenConcept, (v) => _sawConcept = v,
        label: 'sawConcept');
    await _load<double>(
        _settingsRepository.getFontSizeScale, (v) => _fontSize = v,
        label: 'fontSizeScale');
    await _load<bool>(
        _settingsRepository.getKnowledgeQuestEnabled, (v) => _kqEnabled = v,
        label: 'knowledgeQuest');
    await _load<bool>(
        _settingsRepository.getTutorialSkipped, (v) => _tutSkipped = v,
        label: 'tutorialSkipped');
    await _load<bool>(
        _settingsRepository.getTutorialChoiceMade, (v) => _tutChosen = v,
        label: 'tutorialChoiceMade');
    await _load<bool>(_settingsRepository.getJobTutorialCompleted,
        (v) => _jobTutorialCompleted = v,
        label: 'jobTutorialCompleted');
    await _load<bool>(
        _settingsRepository.getDebugModeEnabled, (v) => _debugMode = v,
        label: 'debugMode');
    await _load<bool>(_settingsRepository.getSfxEnabled, (v) => _sfxEnabled = v,
        label: 'sfxEnabled');
    await _load<double>(_settingsRepository.getSfxVolume,
        (v) => _sfxVolume = SfxVolumeSetting(v).value,
        label: 'sfxVolume');
    await _load<bool>(_settingsRepository.getBattleSceneEnabled,
        (v) => _battleSceneEnabled = v,
        label: 'battleSceneEnabled');
    await _load<bool>(_settingsRepository.getMorningNotificationEnabled,
        (v) => _morningNotificationEnabled = v,
        label: 'morningNotification');
    await _load<ThemeMode>(
        _settingsRepository.getThemeMode, (v) => _themeMode = v,
        label: 'themeMode');
    await _load<DateTime?>(
        _settingsRepository.getLastBackupTime, (v) => _lastBackupTime = v,
        label: 'lastBackupTime');

    if (await _tutorial.repairSeenConcept(_tutorialStep, _sawConcept)) {
      _sawConcept = true;
    }
    notifyListeners();
  }

  Future<void> _load<T>(Future<T> Function() loader, void Function(T) setter,
      {String label = ''}) async {
    try {
      setter(await loader());
    } catch (e, st) {
      if (label.isNotEmpty)
        debugPrint('[SettingsVM] $label load error: $e\n$st');
    }
  }
}
