import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';
import 'package:rpg_todo/features/shared/domain/settings_write_result.dart';

/// Hiveの settingsBox / tutorialBox へのアクセスを集約するリポジトリ。
///
/// GameViewModel から直接 Hive.box() を呼んでいた箇所をここに移すことで、
/// 永続化の詳細を隠蔽し、テスト容易性を向上させる。
@lazySingleton
class SettingsRepository {
  /// [logger] は試練で保存失敗ログを検証するための差し替え口。既定は [appLog]。
  SettingsRepository({AppLogger? logger}) : _log = logger ?? appLog;

  final AppLogger _log;

  static const String _settingsBoxName = 'settingsBox';
  static const String _tutorialBoxName = 'tutorialBox';

  /// 保存処理を実行し、失敗を [SettingsWriteResult] として返す（例外は投げない）。
  ///
  /// [save] には既存の `setXxx` を**仮想ディスパッチで**渡す。これにより
  /// 試練のフェイクが override した void setter もそのまま経路に乗る。
  /// ログはここで1回だけ出す（setter 側では出さない）。
  Future<SettingsWriteResult> _write(
    String label,
    Future<void> Function() save,
  ) async {
    try {
      await save();
      return const SettingsWriteResult.success();
    } catch (e, st) {
      _log.warn('設定の保存に失敗しました: $label', e, st);
      return SettingsWriteResult.failure('$labelを保存できませんでした');
    }
  }

  /// 文字サイズの保存結果つきラッパー。
  Future<SettingsWriteResult> writeFontSizeScale(double v) =>
      _write('文字サイズ', () => setFontSizeScale(v));

  /// 学びクエストON/OFFの保存結果つきラッパー。
  Future<SettingsWriteResult> writeKnowledgeQuestEnabled(bool v) =>
      _write('学びクエスト設定', () => setKnowledgeQuestEnabled(v));

  /// 朝通知ON/OFFの保存結果つきラッパー。
  Future<SettingsWriteResult> writeMorningNotificationEnabled(bool v) =>
      _write('朝の通知設定', () => setMorningNotificationEnabled(v));

  /// デバッグモードの保存結果つきラッパー。
  Future<SettingsWriteResult> writeDebugModeEnabled(bool v) =>
      _write('デバッグモード設定', () => setDebugModeEnabled(v));

  /// 魔導書解析AIの保存結果つきラッパー。
  Future<SettingsWriteResult> writeGriffonEnabled(bool v) =>
      _write('魔導書解析AI設定', () => setGriffonEnabled(v));

  /// 効果音ON/OFFの保存結果つきラッパー。
  Future<SettingsWriteResult> writeSfxEnabled(bool v) =>
      _write('効果音設定', () => setSfxEnabled(v));

  /// 効果音音量の保存結果つきラッパー。
  Future<SettingsWriteResult> writeSfxVolume(double v) =>
      _write('効果音の音量', () => setSfxVolume(v));

  /// 戦闘シーンON/OFFの保存結果つきラッパー。
  Future<SettingsWriteResult> writeBattleSceneEnabled(bool v) =>
      _write('戦闘シーン設定', () => setBattleSceneEnabled(v));

  /// テーマモードの保存結果つきラッパー。
  Future<SettingsWriteResult> writeThemeMode(ThemeMode mode) =>
      _write('テーマ設定', () => setThemeMode(mode));

  /// 最終バックアップ日時の保存結果つきラッパー。
  Future<SettingsWriteResult> writeLastBackupTime(DateTime time) =>
      _write('最終バックアップ日時', () => setLastBackupTime(time));

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
    // Hive未初期化の試練環境で open を試みると zone 汚染が起きるため、
    // 開かれていない場合は既定値を返す（getThemeMode と同じ防御）。
    if (!Hive.isBoxOpen(_settingsBoxName)) return true;
    try {
      final box = await _openSettingsBox();
      return box.get('morningNotificationEnabled', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
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

  /// デバッグモードの保存。失敗は例外として呼出元へ伝播する（無音化しない）。
  Future<void> setDebugModeEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('debugModeEnabled', enabled);
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

  /// 魔導書解析AIの保存。失敗は例外として呼出元へ伝播する。
  Future<void> setGriffonEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('griffonEnabled', enabled);
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

  /// 効果音ON/OFFの保存。失敗は例外として呼出元へ伝播する。
  Future<void> setSfxEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('sfxEnabled', enabled);
  }

  /// 効果音の音量（0.0〜1.0）。破損値は既定値へ安全フォールバックする（改善提案#67）。
  Future<double> getSfxVolume() async {
    try {
      final box = await _openSettingsBox();
      return SfxVolumeSetting.fromStored(box.get(SfxVolumeSetting.storageKey))
          .value;
    } catch (_) {
      return SfxVolumeSetting.defaultValue;
    }
  }

  /// 効果音音量の保存。失敗は例外として呼出元へ伝播する。
  Future<void> setSfxVolume(double volume) async {
    final box = await _openSettingsBox();
    await box.put(SfxVolumeSetting.storageKey, SfxVolumeSetting(volume).value);
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

  /// 戦闘シーン設定の保存。失敗は例外として呼出元へ伝播する。
  Future<void> setBattleSceneEnabled(bool enabled) async {
    final box = await _openSettingsBox();
    await box.put('battleSceneEnabled', enabled);
  }

  // ── テーマモード（ライト/ダーク切替） ──────────────────

  Future<ThemeMode> getThemeMode() async {
    // Hive未初期化の試練環境で open を試みると zone 汚染が起きるため、
    // 開かれていない場合は既定値を返す（本番では load() の先行読取で開済み）
    if (!Hive.isBoxOpen(_settingsBoxName)) return ThemeMode.dark;
    try {
      final box = await _openSettingsBox();
      final saved = box.get('themeMode');
      if (saved is int && saved >= 0 && saved <= 2) {
        return ThemeMode.values[saved];
      }
      if (saved is String) {
        return ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.dark,
        );
      }
      return ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  /// テーマモードの保存。失敗は例外として呼出元へ伝播する。
  Future<void> setThemeMode(ThemeMode mode) async {
    final box = await _openSettingsBox();
    await box.put('themeMode', mode.name);
  }

  // ── バックアップ（道標§五#17: 最終バックアップ日時） ──────────────

  /// 保存された最終バックアップ日時を取得。未実行なら null。
  Future<DateTime?> getLastBackupTime() async {
    try {
      final box = await _openSettingsBox();
      final raw = box.get('lastBackupTime') as String?;
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// 最終バックアップ日時を記録する。失敗は例外として呼出元へ伝播する。
  Future<void> setLastBackupTime(DateTime time) async {
    final box = await _openSettingsBox();
    await box.put('lastBackupTime', time.toIso8601String());
  }
}
