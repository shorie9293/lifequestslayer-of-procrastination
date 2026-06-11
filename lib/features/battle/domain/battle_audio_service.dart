import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';

/// 戦闘BGMと効果音を管理するサービス。
///
/// [BattleState] の遷移に応じて適切なBGM/SFXを再生する。
/// 修練場BGMはループ再生、遭遇・戦闘BGMもループ、
/// 勝利/敗北はワンショット再生で自動的に修練場BGMに戻る。
///
/// 使用例:
/// ```dart
/// final audio = BattleAudioService();
/// audio.onBattleStateChanged(BattleState.idle);      // 修練場BGM開始
/// audio.onBattleStateChanged(BattleState.facing);     // 遭遇BGMにクロスフェード
/// audio.onBattleStateChanged(BattleState.attacking);  // 戦闘BGMにクロスフェード
/// audio.onBattleStateChanged(BattleState.victory);    // 勝利ファンファーレ → 修練場BGM
/// audio.onBattleStateChanged(BattleState.defeat);     // 敗北BGM → 修練場BGM
/// ```
class BattleAudioService extends ChangeNotifier {
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  /// 現在再生中のBGMの種類。
  BattleState? _currentBgmState;

  /// クロスフェード中かどうか。
  bool _isCrossfading = false;

  /// マスターボリューム（0.0〜1.0）。
  double _masterVolume = 0.7;

  /// BGMがミュートされているか。
  bool _isBgmMuted = false;

  /// SFXがミュートされているか。
  bool _isSfxMuted = false;

  /// 現在のマスターボリューム。
  double get masterVolume => _masterVolume;

  /// BGMミュート状態。
  bool get isBgmMuted => _isBgmMuted;

  /// SFXミュート状態。
  bool get isSfxMuted => _isSfxMuted;

  /// 現在再生中のBGMの種類（デバッグ用）。
  BattleState? get currentBgmState => _currentBgmState;

  BattleAudioService() {
    _bgmPlayer.onPlayerComplete.listen((_) {
      // BGM再生完了時（ループ終了やワンショット終了）の処理
    });
  }

  // ── 音量・ミュート制御 ──

  /// マスターボリュームを設定する。
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);
    await _bgmPlayer.setVolume(_isBgmMuted ? 0.0 : _masterVolume);
    notifyListeners();
  }

  /// BGMのミュートを切り替える。
  Future<void> toggleBgmMute() async {
    _isBgmMuted = !_isBgmMuted;
    await _bgmPlayer.setVolume(_isBgmMuted ? 0.0 : _masterVolume);
    notifyListeners();
  }

  /// SFXのミュートを切り替える。
  Future<void> toggleSfxMute() async {
    _isSfxMuted = !_isSfxMuted;
    notifyListeners();
  }

  // ── 戦闘状態連動BGM ──

  /// 戦闘状態の変化に応じてBGMを切り替える。
  ///
  /// [newState] に新しい戦闘状態を渡す。
  /// 状態遷移に応じて適切なBGM/SFXを再生する。
  Future<void> onBattleStateChanged(BattleState newState) async {
    if (_isBgmMuted) return;

    switch (newState) {
      case BattleState.idle:
        await _playTrainingGroundBgm();
      case BattleState.facing:
        await _crossfadeToBgm(AudioAsset.bgmEncounter);
      case BattleState.attacking:
        await _crossfadeToBgm(AudioAsset.bgmBattle);
      case BattleState.victory:
        await _playOneShotSfx(AudioAsset.sfxVictory);
        // 勝利ファンファーレ後、修練場BGMに戻る
        Future.delayed(const Duration(seconds: 2), () {
          if (_currentBgmState == BattleState.victory ||
              _currentBgmState == BattleState.defeat) {
            _playTrainingGroundBgm();
          }
        });
      case BattleState.defeat:
        await _playOneShotSfx(AudioAsset.sfxDefeat);
        // 敗北BGM後、修練場BGMに戻る
        Future.delayed(const Duration(seconds: 2), () {
          if (_currentBgmState == BattleState.victory ||
              _currentBgmState == BattleState.defeat) {
            _playTrainingGroundBgm();
          }
        });
    }

    _currentBgmState = newState;
    notifyListeners();
  }

  // ── 内部メソッド ──

  /// 修練場BGMを再生開始する。
  Future<void> _playTrainingGroundBgm() async {
    await _bgmPlayer.stop();
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.play(AssetSource(AudioAsset.bgmTrainingGround));
  }

  /// BGMをクロスフェードで切り替える。
  ///
  /// 現在のBGMをフェードアウトしながら新しいBGMをフェードインする。
  Future<void> _crossfadeToBgm(String assetPath) async {
    if (_isCrossfading) return;
    _isCrossfading = true;

    // フェードアウト（簡易版: 直接切り替え）
    await _bgmPlayer.stop();

    // 新しいBGMを再生
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.play(AssetSource(assetPath));

    _isCrossfading = false;
  }

  /// ワンショットSEを再生する。
  Future<void> _playOneShotSfx(String assetPath) async {
    if (_isSfxMuted) return;
    await _sfxPlayer.stop();
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _sfxPlayer.play(AssetSource(assetPath));
  }

  /// 全BGMを停止する（アプリ終了時など）。
  Future<void> stopAll() async {
    await _bgmPlayer.stop();
    await _sfxPlayer.stop();
    _currentBgmState = null;
    notifyListeners();
  }

  /// リソースを解放する。
  @override
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }
}

/// オーディオアセットのパス定数。
class AudioAsset {
  AudioAsset._();

  /// 修練場BGM（ループ）。
  static const String bgmTrainingGround = 'audio/bgm_training_ground.mp3';

  /// 遭遇BGM（ループ）。
  static const String bgmEncounter = 'audio/bgm_encounter.mp3';

  /// 戦闘BGM（ループ）。
  static const String bgmBattle = 'audio/bgm_battle.mp3';

  /// 勝利ファンファーレ（ワンショット）。
  static const String sfxVictory = 'audio/sfx_victory.mp3';

  /// 敗北BGM（ワンショット）。
  static const String sfxDefeat = 'audio/sfx_defeat.mp3';
}
