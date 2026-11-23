import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/text/text_scale_composition.dart';

/// 非線形スケーリング（Android 14+）を模した試験用スケーラ。
///
/// 14sp 以下は等倍、それを超えると 1.5 倍になる段階的なスケーラ。
/// アプリ内倍率が「元のフォントサイズ」に掛かっているか（＝base.scale の前か後か）
/// を 12sp で判別できる。
class _StepTextScaler implements TextScaler {
  const _StepTextScaler();

  @override
  double scale(double fontSize) => fontSize <= 14 ? fontSize : fontSize * 1.5;

  @override
  double get textScaleFactor => 1.5;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) =>
      this;
}

void main() {
  group('composeTextScaler（純粋合成）', () {
    test('端末設定2.0＋アプリ設定1.0 → 実効2.0（OS設定を捨てない）', () {
      final scaler =
          composeTextScaler(const TextScaler.linear(2.0), 1.0);
      expect(scaler.scale(16), 32.0);
      // 置換実装（TextScaler.linear(1.0)）へ戻すとここが 16.0 になり RED。
      expect(scaler.scale(16), isNot(16.0));
    });

    test('端末設定1.0＋アプリ設定1.25 → 実効1.25（アプリ設定も無効化されない）', () {
      final scaler =
          composeTextScaler(const TextScaler.linear(1.0), 1.25);
      expect(scaler.scale(16), 20.0);
    });

    test('端末設定1.5＋アプリ設定1.2 → 乗算で実効1.8', () {
      final scaler =
          composeTextScaler(const TextScaler.linear(1.5), 1.2);
      expect(scaler.scale(10), closeTo(18.0, 1e-9));
    });

    test('非線形スケーラを基点にしても倍率は元サイズへ掛かる', () {
      // 12sp → ×1.5 = 18sp → base(18sp) = 27sp。
      // 逆順（base を先に適用）なら 12sp → 12sp → ×1.5 = 18sp になり RED。
      final scaler = composeTextScaler(const _StepTextScaler(), 1.5);
      expect(scaler.scale(12), 27.0);
    });

    test('倍率1.0は端末設定そのものと一致する（後方互換）', () {
      final system = const TextScaler.linear(1.3);
      final scaler = composeTextScaler(system, 1.0);
      expect(scaler.scale(14), system.scale(14));
    });

    test('clamp は倍率のみを制限し基点スケーラを保つ', () {
      final scaler =
          composeTextScaler(const TextScaler.linear(2.0), 1.2).clamp(
        minScaleFactor: 0.5,
        maxScaleFactor: 1.0,
      );
      expect(scaler.scale(10), 20.0); // 2.0 × 1.0 × 10
    });
  });

  group('composeWithSystemTextScaler（端末設定の取り出し）', () {
    testWidgets('MaterialApp.builder の context から端末設定2.0を取り、アプリ倍率と乗算する',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      late TextScaler result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            result = composeWithSystemTextScaler(context, 1.25);
            return child ?? const SizedBox.shrink();
          },
          home: const SizedBox.shrink(),
        ),
      );

      // 端末2.0 × アプリ1.25 = 2.5。旧実装（TextScaler.linear(1.25)）なら 20.0 で RED。
      expect(result.scale(16), 40.0);
    });
  });
}
