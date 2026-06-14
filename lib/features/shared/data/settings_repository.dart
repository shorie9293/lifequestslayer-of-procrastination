import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

/// Hiveの settingsBox / tutorialBox へのアクセスを集約するリポジトリ。
///
/// GameViewModel から直接 Hive.box() を呼んでいた箇所をここに移すことで、
/// 永続化の詳細を隠蔽し、テスト容易性を向上させる。
@lazySingleton
class SettingsRepository {
  static const String _settingsBoxName = 'settingsBox';
  static const String _tutorialBoxName = 'tutorialBox';

  // ── settingsBox ──────────────────────────────────────────

  Future<Box> _openSettingsBox() => Hive.openBox(_settingsBoxName);

  Future<double> getFontSizeScale() async {
    final box = await _openSettingsBox();
    final saved = box.get('fontSizeScale', defaultValue: 0.85) as double;
    return saved > 1.2 ? 1.2 : saved;
  }

  Future<void> setFontSizeScale(double scale) async {
    final box = await _openSettingsBox();
    await box.put('fontSizeScale', scale);
  }

  Future<bool> getKnowledgeQuestEnabled() async {
    final box = await _openSettingsBox();
    return box.get('knowledgeQuestEnabled', defaultValue: true) as bool;
  }

  Future<void> setKnowledgeQuestEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('knowledgeQuestEnabled', enabled);
  }

  /// 疲労MAXポップアップを表示した日付を保存（アプリ再起動後も維持）
  Future<void> saveFatiguePopupDate(DateTime date) async {
    final box = await _openSettingsBox();
    await box.put('fatiguePopupDate', date.toIso8601String());
  }

  /// 保存された疲労ポップアップ日付を取得
  Future<DateTime?> getFatiguePopupDate() async {
    final box = await _openSettingsBox();
    final raw = box.get('fatiguePopupDate') as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> deleteFatiguePopupDate() async {
    final box = await _openSettingsBox();
    await box.delete('fatiguePopupDate');
  }

  // ── tutorialBox ──────────────────────────────────────────

  Future<Box> _openTutorialBox() => Hive.openBox(_tutorialBoxName);

  Future<int> getTutorialStep() async {
    final box = await _openTutorialBox();
    return box.get('step', defaultValue: 0);
  }

  Future<void> setTutorialStep(int step) async {
    final box = await _openTutorialBox();
    await box.put('step', step);
  }

  Future<bool> getHasSeenConcept() async {
    final box = await _openTutorialBox();
    return box.get('hasSeenConcept', defaultValue: false);
  }

  Future<void> setHasSeenConcept(bool value) async {
    final box = await _openTutorialBox();
    await box.put('hasSeenConcept', value);
  }

  Future<bool> getTutorialSkipped() async {
    final box = await _openTutorialBox();
    return box.get('skipped', defaultValue: false);
  }

  Future<void> setTutorialSkipped(bool value) async {
    final box = await _openTutorialBox();
    await box.put('skipped', value);
  }

  Future<bool> getTutorialChoiceMade() async {
    final box = await _openTutorialBox();
    return box.get('choiceMade', defaultValue: false);
  }

  Future<void> setTutorialChoiceMade(bool value) async {
    final box = await _openTutorialBox();
    await box.put('choiceMade', value);
  }

  Future<bool> getJobTutorialCompleted() async {
    final box = await _openTutorialBox();
    return box.get('jobTutorialCompleted', defaultValue: false) as bool;
  }

  Future<void> setJobTutorialCompleted(bool value) async {
    final box = await _openTutorialBox();
    await box.put('jobTutorialCompleted', value);
  }

  Future<void> resetTutorial() async {
    final box = await _openTutorialBox();
    await box.put('step', 0);
    await box.put('hasSeenConcept', false);
    await box.put('skipped', false);
    await box.put('choiceMade', false);
    await box.put('jobTutorialCompleted', false);
  }

  // ── 通知設定（個別ON/OFF） ──────────────────────────────

  Future<bool> getMorningNotificationEnabled() async {
    final box = await _openSettingsBox();
    return box.get('morningNotificationEnabled', defaultValue: true) as bool;
  }

  Future<void> setMorningNotificationEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('morningNotificationEnabled', enabled);
  }

  Future<bool> getEveningNotificationEnabled() async {
    final box = await _openSettingsBox();
    return box.get('eveningNotificationEnabled', defaultValue: true) as bool;
  }

  Future<void> setEveningNotificationEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('eveningNotificationEnabled', enabled);
  }

  Future<bool> getNoonNotificationEnabled() async {
    final box = await _openSettingsBox();
    return box.get('noonNotificationEnabled', defaultValue: true) as bool;
  }

  Future<void> setNoonNotificationEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('noonNotificationEnabled', enabled);
  }

  // ── デバッグモード ─────────────────────────────────────

  Future<bool> getDebugModeEnabled() async {
    try {
      final box = await _openSettingsBox();
      return box.get('debugModeEnabled', defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> setDebugModeEnabled(bool enabled) async {
    try {
      final box = await _openSettingsBox();
      await box.put('debugModeEnabled', enabled);
    } catch (_) {}
  }

  // ── 魔導書解析AI（Griffon） ────────────────────────────

  /// 魔導書解析AI（GriffonEstimator）の有効/無効フラグ。
  ///
  /// デフォルトは false（キーワードベース推定のみ）。
  /// AI推定が有効な場合、クエスト作成時に過去の完了クエスト履歴から
  /// 難易度と見積もり時間をAIが提案する。
  Future<bool> getGriffonEnabled() async {
    try {
      final box = await _openSettingsBox();
      return box.get('griffonEnabled', defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> setGriffonEnabled(bool enabled) async {
    try {
      final box = await _openSettingsBox();
      await box.put('griffonEnabled', enabled);
    } catch (_) {}
  }

  // ── 効果音（SFX） ─────────────────────────────────────

  Future<bool> getSfxEnabled() async {
    try {
      final box = await _openSettingsBox();
      return box.get('sfxEnabled', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    try {
      final box = await _openSettingsBox();
      await box.put('sfxEnabled', enabled);
    } catch (_) {}
  }

  // ── 戦闘シーン（討伐演出） ──────────────────────────

  Future<bool> getBattleSceneEnabled() async {
    try {
      final box = await _openSettingsBox();
      return box.get('battleSceneEnabled', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  Future<void> setBattleSceneEnabled(bool enabled) async {
    try {
      final box = await _openSettingsBox();
      await box.put('battleSceneEnabled', enabled);
    } catch (_) {}
  }
}
