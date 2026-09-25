/// 効果音の音量設定（純粋モデル）。
///
/// Flutter ウィジェットに依存しないドメインモデル。
/// 音量は常に 0.0〜1.0 にクランプ済みで保持され、
/// 破損値（NaN・範囲外・非num）からの安全フォールバックを提供する。
class SfxVolumeSetting {
  static const double minValue = 0.0;
  static const double maxValue = 1.0;
  static const double defaultValue = 0.7;
  static const List<double> presets = <double>[0.0, 0.25, 0.5, 0.75, 1.0];
  static const String storageKey = 'sfxVolume';

  /// 0.0〜1.0 にクランプ済みの値（NaN/範囲外/破損値は安全側へ）。
  final double value;

  SfxVolumeSetting(double raw) : value = _sanitize(raw);

  /// NaN → defaultValue、範囲外 → clamp、それ以外はそのまま。
  static double _sanitize(double raw) {
    if (raw.isNaN) return defaultValue;
    if (raw < minValue) return minValue;
    if (raw > maxValue) return maxValue;
    return raw;
  }

  /// 音量のパーセント表現（(value*100).round()）。
  int get percent => (value * 100).round();

  /// 「70%」形式の表示ラベル。
  String get percentLabel => '$percent%';

  /// 音量帯の表示ラベル。
  String get label {
    if (value <= 0.0) return '消音';
    if (value <= 0.3) return '小';
    if (value <= 0.6) return '中';
    if (value <= 0.85) return '大';
    return '最大';
  }

  /// 消音状態かどうか（value <= minValue）。
  bool get isMuted => value <= minValue;

  /// 保存値（null/非num/NaN/範囲外 → defaultValue の安全フォールバック）。
  static SfxVolumeSetting fromStored(Object? stored) {
    if (stored is! num) return SfxVolumeSetting(defaultValue);
    final raw = stored.toDouble();
    if (raw.isNaN) return SfxVolumeSetting(defaultValue);
    if (raw < minValue || raw > maxValue) {
      return SfxVolumeSetting(defaultValue);
    }
    return SfxVolumeSetting(raw);
  }

  /// Hive へ保存する値。
  double toStored() => value;

  /// value のみで等価比較（exact）。
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SfxVolumeSetting && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
