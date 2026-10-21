import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';

void main() {
  group('ReduceMotionSetting.fromStorageKey', () {
    test('既知の storageKey は対応する値を返す', () {
      expect(ReduceMotionSetting.fromStorageKey('system'),
          ReduceMotionSetting.system);
      expect(
          ReduceMotionSetting.fromStorageKey('off'), ReduceMotionSetting.off);
      expect(ReduceMotionSetting.fromStorageKey('on'), ReduceMotionSetting.on);
    });

    test('未知の文字列は system にフォールバックする', () {
      expect(ReduceMotionSetting.fromStorageKey('bogus'),
          ReduceMotionSetting.system);
      expect(ReduceMotionSetting.fromStorageKey(''),
          ReduceMotionSetting.system);
    });

    test('null は system にフォールバックする', () {
      expect(ReduceMotionSetting.fromStorageKey(null),
          ReduceMotionSetting.system);
    });
  });

  group('ReduceMotionSetting.next', () {
    test('system → off → on → system の順で巡回する', () {
      expect(ReduceMotionSetting.system.next, ReduceMotionSetting.off);
      expect(ReduceMotionSetting.off.next, ReduceMotionSetting.on);
      expect(ReduceMotionSetting.on.next, ReduceMotionSetting.system);
    });
  });

  group('ReduceMotionSetting.forceDisableAnimations', () {
    test('on は true（アニメーション抑止）', () {
      expect(ReduceMotionSetting.on.forceDisableAnimations, isTrue);
    });

    test('off は false（端末設定より優先して有効化）', () {
      expect(ReduceMotionSetting.off.forceDisableAnimations, isFalse);
    });

    test('system は null（端末設定を尊重）', () {
      expect(ReduceMotionSetting.system.forceDisableAnimations, isNull);
    });
  });

  group('applyReduceMotion', () {
    const base = MediaQueryData(
      textScaler: TextScaler.linear(1.3),
      disableAnimations: false,
    );

    test('on は disableAnimations を true にする', () {
      final applied = applyReduceMotion(base, ReduceMotionSetting.on);
      expect(applied.disableAnimations, isTrue);
    });

    test('off は disableAnimations を false にする', () {
      const reduceByOs = MediaQueryData(
        textScaler: TextScaler.linear(1.3),
        disableAnimations: true,
      );
      final applied = applyReduceMotion(reduceByOs, ReduceMotionSetting.off);
      expect(applied.disableAnimations, isFalse);
    });

    test('system は元の MediaQueryData をそのまま返す（他属性も保持）', () {
      final applied = applyReduceMotion(base, ReduceMotionSetting.system);
      expect(applied.disableAnimations, isFalse);
      expect(applied.textScaler.scale(10), 13);
      expect(identical(applied, base), isTrue,
          reason: 'forced が null なら同一インスタンスを返す');
    });
  });
}
