import 'package:hive/hive.dart';

/// Hiveの settingsBox / tutorialBox へのアクセスを集約するリポジトリ。
///
/// GameViewModel から直接 Hive.box() を呼んでいた箇所をここに移すことで、
/// 永続化の詳細を隠蔽し、テスト容易性を向上させる。
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

  Future<void> resetTutorial() async {
    final box = await _openTutorialBox();
    await box.put('step', 0);
    await box.put('hasSeenConcept', false);
    await box.put('skipped', false);
    await box.put('choiceMade', false);
  }
}
