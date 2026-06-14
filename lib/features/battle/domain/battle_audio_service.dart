import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 効果音（SFX）を管理するサービス。
///
/// BGMは廃止。効果音のみワンショット再生する。
/// SFXのオン/オフは [SettingsViewModel.isSfxEnabled] で制御される。
class BattleAudioService extends ChangeNotifier {
  final AudioPlayer _sfxPlayer = AudioPlayer();

  /// SFXが有効かどうか（外部のSettingsViewModelから制御）。
  bool _sfxEnabled = true;

  /// SFX有効状態。
  bool get sfxEnabled => _sfxEnabled;

  BattleAudioService();

  /// SFXの有効/無効を設定する（SettingsViewModelから呼ばれる）。
  void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
    notifyListeners();
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
