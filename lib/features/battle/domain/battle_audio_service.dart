import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';

/// 効果音（SFX）を管理するサービス。
///
/// BGMは廃止。効果音のみワンショット再生する。
/// SFXのオン/オフは [SettingsViewModel.isSfxEnabled] で制御される。
class BattleAudioService extends ChangeNotifier {
  final AudioPlayer _sfxPlayer = AudioPlayer();

  /// SFXが有効かどうか（外部のSettingsViewModelから制御）。
  bool _sfxEnabled = true;

  /// SFXの音量（0.0〜1.0、クランプ済み）。
  double _volume = SfxVolumeSetting.defaultValue;

  /// SFX有効状態。
  bool get sfxEnabled => _sfxEnabled;

  /// SFX音量（0.0〜1.0）。
  double get volume => _volume;

  BattleAudioService();

  /// SFXの有効/無効を設定する（SettingsViewModelから呼ばれる）。
  void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
    notifyListeners();
  }

  /// SFXの音量を設定する（SettingsViewModelから呼ばれる）。
  ///
  /// audioplayers の setVolume は **await してはならない** — flutter_test では
  /// プラットフォームチャネルが応答せず await が完了しない（試練が30秒timeout）。
  /// 状態更新は同期で行い、再生器への反映は投げっぱなしにする。
  void setVolume(double v) {
    _volume = SfxVolumeSetting(v).value;
    _applyVolumeToPlayer();
    notifyListeners();
  }

  /// 現在の音量を再生器へ反映する（失敗は無視＝headless・未対応端末）。
  void _applyVolumeToPlayer() {
    try {
      _sfxPlayer.setVolume(_volume).then((_) {}, onError: (Object _) {});
    } catch (_) {}
  }

  /// 勝利ファンファーレを再生する。
  Future<void> playVictory() async {
    await _playOneShot(SfxAsset.sfxVictory);
  }

  /// 敗北効果音を再生する。
  Future<void> playDefeat() async {
    await _playOneShot(SfxAsset.sfxDefeat);
  }

  /// ワンショットSEを再生する。
  Future<void> _playOneShot(String assetPath) async {
    if (!_sfxEnabled) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    // 再生直前に音量を確実に反映する（awaitしない）
    _applyVolumeToPlayer();
    await _sfxPlayer.play(AssetSource(assetPath));
  }

  /// 全音声を停止する（アプリ中断時など）。
  Future<void> stopAll() async {
    await _sfxPlayer.stop();
    notifyListeners();
  }

  /// リソースを解放する。
  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }
}

/// 効果音アセットのパス定数。
class SfxAsset {
  SfxAsset._();

  /// 勝利ファンファーレ（ワンショット）。
  static const String sfxVictory = 'audio/sfx_victory.mp3';

  /// 敗北効果音（ワンショット）。
  static const String sfxDefeat = 'audio/sfx_defeat.mp3';
}
