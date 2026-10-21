// 親探針（合成の不変条件）: 画面→リポジトリ→再読込→MediaQuery までが一本に繋がるか。
// 眷属は「モデル」「保存」「画面」を個別にしか撃たないため、親が横断で撃つ。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/settings/presentation/reduce_motion_settings_screen.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';

void main() {
  test('合成: 端末が動きを許可していても on なら disableAnimations=true', () {
    const platform = MediaQueryData(disableAnimations: false);
    expect(applyReduceMotion(platform, ReduceMotionSetting.on).disableAnimations,
        isTrue);
    expect(applyReduceMotion(platform, ReduceMotionSetting.off).disableAnimations,
        isFalse);
    // system は端末設定をそのまま尊重する（false を true にしない）
    expect(
        applyReduceMotion(platform, ReduceMotionSetting.system).disableAnimations,
        isFalse);
    // 端末が「動きを減らす」なら system でも保持される
    expect(
        applyReduceMotion(const MediaQueryData(disableAnimations: true),
                ReduceMotionSetting.system)
            .disableAnimations,
        isTrue);
    // textScaler など他のフィールドは壊さない
    final src = MediaQueryData(textScaler: const TextScaler.linear(1.3));
    final dst = applyReduceMotion(src, ReduceMotionSetting.on);
    expect(dst.textScaler.scale(10), closeTo(13, 0.001));
  });

  testWidgets('画面で選ぶ→リポジトリ保存→再読込→MediaQueryへ反映', (tester) async {
    final repo = InMemoryReduceMotionRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReduceMotionSettingsScreen(repository: repo)),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('reduce_motion_option_on')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.saved, ReduceMotionSetting.on,
        reason: '画面の選択がリポジトリ保存へ到達していない');
    final loaded = await repo.load();
    expect(loaded, ReduceMotionSetting.on);
    final applied =
        applyReduceMotion(const MediaQueryData(disableAnimations: false), loaded!);
    expect(applied.disableAnimations, isTrue, reason: 'MediaQueryへ反映されない');
  });

  test('根部配線: main.dart が applyReduceMotion を通している', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('applyReduceMotion'), isTrue,
        reason: 'main.dart の builder に applyReduceMotion が無い（設定が画面で止まっている）');
    expect(src.contains('ReduceMotionViewModel'), isTrue);
  });
}
