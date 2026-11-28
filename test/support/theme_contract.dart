// ライトテーマの文字色契約（画面走査で背景を解決できない Material 面の担保）。
//
// 振り返りの杜の走査は RenderDecoratedBox の色のみを見るため、FilledButton 等の
// Material 面は走査で背景を解決できない。その分は colorScheme の契約（各面での
// onSurface / onPrimary の比と、本文墨色の輝度）で担保する。
//
// 判定ロジックは contrast_gate.dart の contrastRatio を再利用し、ここに複製しない。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

import 'contrast_gate.dart';

/// ライトテーマの文字色契約を 1 本の test として登録する。
void runLightThemeContrastContract() {
  test('ライトテーマの文字色契約: onSurface / onPrimary が各面で 3.0:1 以上', () {
    for (final job in Job.values) {
      final theme = GameThemes.lightForJob(job);
      final scheme = theme.colorScheme;
      final onSurface =
          contrastRatio(scheme.onSurface, theme.scaffoldBackgroundColor);
      final onSurfaceCard = contrastRatio(scheme.onSurface, scheme.surface);
      final onPrimary = contrastRatio(scheme.onPrimary, scheme.primary);
      // ignore: avoid_print
      print('${job.name}: onSurface=$onSurface onSurface(surface)=' 
          '$onSurfaceCard onPrimary=$onPrimary');

      expect(theme.brightness, Brightness.light);
      expect(onSurface, greaterThanOrEqualTo(4.5),
          reason: '${job.name}: onSurface が地色に対して不足');
      expect(onSurfaceCard, greaterThanOrEqualTo(4.5),
          reason: '${job.name}: onSurface が surface に対して不足');
      expect(onPrimary, greaterThanOrEqualTo(3.0),
          reason: '${job.name}: onPrimary が primary に対して不足');
      expect(
          theme.textTheme.bodyMedium!.color!.computeLuminance(), lessThan(0.3));
    }
  });
}