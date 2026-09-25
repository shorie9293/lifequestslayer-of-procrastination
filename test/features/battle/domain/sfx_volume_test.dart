import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/sfx_volume.dart';

/// 効果音の音量設定（SfxVolumeSetting）の試練。
///
/// 純粋モデルなので Flutter ウィジェット不要、TDD の基幹となる試練群。
/// 凍結API仕様に従い、境界値と破損値からの安全フォールバックを検証する。
void main() {
  group('SfxVolumeSetting - 定数', () {
    test('定数は凍結API仕様どおり', () {
      expect(SfxVolumeSetting.minValue, 0.0);
      expect(SfxVolumeSetting.maxValue, 1.0);
      expect(SfxVolumeSetting.defaultValue, 0.7);
      expect(SfxVolumeSetting.presets, [0.0, 0.25, 0.5, 0.75, 1.0]);
      expect(SfxVolumeSetting.storageKey, 'sfxVolume');
    });
  });

  group('SfxVolumeSetting - コンストラクタ（クランプ）', () {
    test('既定値 0.7 はそのまま保持される', () {
      expect(SfxVolumeSetting(0.7).value, 0.7);
    });

    test('範囲内の中間値はそのまま保持される', () {
      expect(SfxVolumeSetting(0.25).value, 0.25);
      expect(SfxVolumeSetting(0.5).value, 0.5);
      expect(SfxVolumeSetting(0.85).value, 0.85);
    });

    test('NaN は defaultValue に置き換わる', () {
      final setting = SfxVolumeSetting(double.nan);
      expect(setting.value, SfxVolumeSetting.defaultValue);
    });

    test('範囲外（-1）は minValue にクランプされる', () {
      expect(SfxVolumeSetting(-1).value, 0.0);
    });

    test('範囲外（2）は maxValue にクランプされる', () {
      expect(SfxVolumeSetting(2).value, 1.0);
    });

    test('境界値 0.0 と 1.0 はそのまま保持される', () {
      expect(SfxVolumeSetting(0.0).value, 0.0);
      expect(SfxVolumeSetting(1.0).value, 1.0);
    });
  });

  group('SfxVolumeSetting - percent / percentLabel', () {
    test('percent は (value*100).round()', () {
      expect(SfxVolumeSetting(0.7).percent, 70);
      expect(SfxVolumeSetting(0.0).percent, 0);
      expect(SfxVolumeSetting(1.0).percent, 100);
      expect(SfxVolumeSetting(0.25).percent, 25);
      expect(SfxVolumeSetting(0.5).percent, 50);
      expect(SfxVolumeSetting(0.75).percent, 75);
    });

    test('percentLabel は「<percent>%」形式', () {
      expect(SfxVolumeSetting(0.7).percentLabel, '70%');
      expect(SfxVolumeSetting(0.0).percentLabel, '0%');
      expect(SfxVolumeSetting(1.0).percentLabel, '100%');
    });
  });

  group('SfxVolumeSetting - label の境界', () {
    test('presets 各値のラベル', () {
      expect(SfxVolumeSetting(0.0).label, '消音');
      expect(SfxVolumeSetting(0.25).label, '小');
      expect(SfxVolumeSetting(0.5).label, '中');
      expect(SfxVolumeSetting(0.75).label, '大');
      expect(SfxVolumeSetting(1.0).label, '最大');
    });

    test('境界値 0.0 / 0.3 / 0.6 / 0.85 は仕様どおりのラベル', () {
      // <=0.0 → 消音 / <=0.3 → 小 / <=0.6 → 中 / <=0.85 → 大 / else → 最大
      expect(SfxVolumeSetting(0.0).label, '消音');
      expect(SfxVolumeSetting(0.3).label, '小');
      expect(SfxVolumeSetting(0.6).label, '中');
      expect(SfxVolumeSetting(0.85).label, '大');
      // 境界直上は次の帯域へ
      expect(SfxVolumeSetting(0.86).label, '最大');
    });
  });

  group('SfxVolumeSetting - isMuted', () {
    test('value が minValue 以下で true', () {
      expect(SfxVolumeSetting(0.0).isMuted, isTrue);
      expect(SfxVolumeSetting(-1).isMuted, isTrue); // クランプ後 0.0
    });

    test('value が minValue を超えれば false', () {
      expect(SfxVolumeSetting(0.7).isMuted, isFalse);
      expect(SfxVolumeSetting(0.1).isMuted, isFalse);
    });
  });

  group('SfxVolumeSetting - fromStored（安全フォールバック）', () {
    test('null は defaultValue', () {
      expect(SfxVolumeSetting.fromStored(null).value,
          SfxVolumeSetting.defaultValue);
    });

    test('非num（文字列）は defaultValue', () {
      expect(SfxVolumeSetting.fromStored('loud').value,
          SfxVolumeSetting.defaultValue);
    });

    test('bool も非num扱いで defaultValue', () {
      expect(SfxVolumeSetting.fromStored(true).value,
          SfxVolumeSetting.defaultValue);
    });

    test('NaN は defaultValue', () {
      expect(SfxVolumeSetting.fromStored(double.nan).value,
          SfxVolumeSetting.defaultValue);
    });

    test('範囲外（-1・2）は defaultValue（フォールバック）', () {
      expect(SfxVolumeSetting.fromStored(-1).value,
          SfxVolumeSetting.defaultValue);
      expect(SfxVolumeSetting.fromStored(2).value,
          SfxVolumeSetting.defaultValue);
    });

    test('正常値（num）はその値を double 化して保持', () {
      expect(SfxVolumeSetting.fromStored(0.25).value, 0.25);
      expect(SfxVolumeSetting.fromStored(1).value, 1.0); // int 1 も受理
    });
  });

  group('SfxVolumeSetting - toStored / 等価性', () {
    test('toStored は value をそのまま返す', () {
      expect(SfxVolumeSetting(0.7).toStored(), 0.7);
      expect(SfxVolumeSetting(2).toStored(), 1.0); // クランプ後
    });

    test('等価性: value が同じなら等しい', () {
      expect(SfxVolumeSetting(0.7), SfxVolumeSetting(0.7));
      expect(SfxVolumeSetting(-1), SfxVolumeSetting(0.0)); // クランプ後同一視
    });

    test('等価性: value が異なれば等しくない', () {
      expect(SfxVolumeSetting(0.7) == SfxVolumeSetting(0.5), isFalse);
    });

    test('hashCode は value のみに依存する', () {
      expect(SfxVolumeSetting(0.7).hashCode, SfxVolumeSetting(0.7).hashCode);
      expect(
        SfxVolumeSetting(2).hashCode,
        SfxVolumeSetting(1.0).hashCode,
      );
    });
  });
}
