import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';

/// BattleAudioService の音量設定の試練。
///
/// headless試練ではプラットフォームチャネルが無いため、
/// 再生器への反映は投げっぱなし（awaitしない）設計になっている。
/// ここでは状態（volume getter）の振る舞いのみを検証する。
void main() {
  // AudioPlayer は ServicesBinding とプラットフォームチャネルを要求するため、
  // 試練ではバインディング初期化＋モックチャネルで無害化する
  TestWidgetsFlutterBinding.ensureInitialized();
  const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const playerChannel = MethodChannel('xyz.luan/audioplayers');

  group('BattleAudioService - 音量（volume / setVolume）', () {
    late BattleAudioService service;

    setUp(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(globalChannel, (call) async => null);
      messenger.setMockMethodCallHandler(playerChannel, (call) async => null);
      service = BattleAudioService();
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(globalChannel, null);
      messenger.setMockMethodCallHandler(playerChannel, null);
    });

    test('既定の volume は defaultValue', () {
      expect(service.volume, SfxVolumeSetting.defaultValue);
      expect(SfxVolumeSetting.defaultValue, 0.7);
    });

    test('setVolume が範囲内の値をそのまま反映する', () {
      service.setVolume(0.25);
      expect(service.volume, 0.25);
    });

    test('setVolume が範囲外（2）をクランプして反映する', () {
      service.setVolume(2);
      expect(service.volume, 1.0);
    });

    test('setVolume が範囲外（-1）をクランプして反映する', () {
      service.setVolume(-1);
      expect(service.volume, 0.0);
    });

    test('setVolume(NaN) は defaultValue にフォールバック', () {
      service.setVolume(double.nan);
      expect(service.volume, SfxVolumeSetting.defaultValue);
    });

    test('setVolume は範囲外でも例外を投げない', () {
      expect(() => service.setVolume(999), returnsNormally);
      expect(() => service.setVolume(-999), returnsNormally);
      expect(service.volume, 0.0); // -999 はクランプ後 0.0
    });

    test('境界値 0.0 を反映する', () {
      service.setVolume(0.0);
      expect(service.volume, 0.0);
    });

    test('境界値 1.0 を反映する', () {
      service.setVolume(1.0);
      expect(service.volume, 1.0);
    });

    test('setVolume はリスナーへ通知する', () {
      var notified = 0;
      service.addListener(() => notified++);
      service.setVolume(0.5);
      expect(notified, 1);
    });
  });
}
