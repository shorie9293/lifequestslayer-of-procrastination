import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// アイコンリソースの回帰防止（高天原 icon forge）
///
/// アダプティブアイコンは「置いたつもりで効いていない」ことが静かに起きる:
/// - mipmap-anydpi-v26 が無い → レガシーPNGのまま縮小され、小サイズで潰れる
/// - `<monochrome>` 層が無い → Android 13+ のテーマアイコン（Nothing OS等）で
///   正しく描けない
/// - 密度ごとの PNG が欠ける → 端末によって解像度が落ちる
void main() {
  const res = 'android/app/src/main/res';

  test('adaptive icon XML が存在し monochrome 層を持つ', () {
    for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final f = File('$res/mipmap-anydpi-v26/$name');
      expect(f.existsSync(), isTrue, reason: '$name が無い（アダプティブアイコン未対応）');
      final xml = f.readAsStringSync();
      expect(xml.contains('<adaptive-icon'), isTrue);
      expect(xml.contains('<foreground'), isTrue);
      expect(xml.contains('<monochrome'), isTrue,
          reason: '$name に monochrome 層が無い（テーマアイコンで描けない）');
    }
  });

  test('foreground / monochrome の VectorDrawable が存在する', () {
    for (final name in ['ic_launcher_foreground.xml', 'ic_launcher_monochrome.xml']) {
      final f = File('$res/drawable/$name');
      expect(f.existsSync(), isTrue, reason: '$name が無い');
      final xml = f.readAsStringSync();
      expect(xml.contains('<vector'), isTrue);
      expect(xml.contains('android:pathData'), isTrue);
    }
  });

  test('全密度のレガシーPNGが存在し、背景が透明である', () {
    const densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final entry in densities.entries) {
      for (final name in ['ic_launcher.png', 'ic_launcher_round.png']) {
        final f = File('$res/mipmap-${entry.key}/$name');
        expect(f.existsSync(), isTrue, reason: 'mipmap-${entry.key}/$name が無い');
        expect(f.lengthSync(), greaterThan(100), reason: '$name が空');
      }
    }
  });
}
