import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/combo_system.dart';

void main() {
  /// テスト用の固定時刻を返すクロック。
  DateTime now = DateTime(2026, 6, 7, 12, 0, 0);
  DateTime fixedClock() => now;

  /// 時刻を進めるヘルパー。
  void advance(Duration d) => now = now.add(d);

  group('ComboSystem', () {
    group('初期状態', () {
      test('コンボ数0、倍率1.0', () {
        final combo = ComboSystem(clock: fixedClock);
        expect(combo.comboCount, 0);
        expect(combo.currentMultiplier, 1.0);
        expect(combo.isComboActive, false);
        expect(combo.lastCombatTime, null);
      });
    });

    group('onVictory', () {
      test('討伐成功でコンボ数が増加', () {
        final combo = ComboSystem(clock: fixedClock);
        combo.onVictory();
        expect(combo.comboCount, 1);
        combo.onVictory();
        expect(combo.comboCount, 2);
        combo.onVictory();
        expect(combo.comboCount, 3);
      });

      test('コンボ倍率が正しく計算される', () {
        final combo = ComboSystem(clock: fixedClock);
        // combo=0: multiplier=1.0
        expect(combo.currentMultiplier, 1.0);

        combo.onVictory(); // combo=1
        expect(combo.currentMultiplier, 1.0); // combo=1 ではまだ倍率なし

        combo.onVictory(); // combo=2
        expect(combo.currentMultiplier, 1.1); // 1.0 + (2-1)*0.1

        combo.onVictory(); // combo=3
        expect(combo.currentMultiplier, 1.2); // 1.0 + (3-1)*0.1

        // 10コンボまでテスト
        for (int i = 4; i <= 10; i++) {
          combo.onVictory();
        }
        expect(combo.comboCount, 10);
        expect(combo.currentMultiplier, closeTo(1.9, 0.001));
      });

      test('コンボ倍率が上限を超えない', () {
        final combo = ComboSystem(
          clock: fixedClock,
          maxMultiplier: 3.0,
          multiplierStep: 0.1,
        );
        // 20連勝しても上限 3.0 で止まる
        for (int i = 0; i < 40; i++) {
          combo.onVictory();
        }
        expect(combo.currentMultiplier, 3.0);
      });
    });

    group('タイムアウト', () {
      test('30分以内の討伐ではコンボ継続', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(clock: fixedClock);

        combo.onVictory(); // combo=1
        advance(const Duration(minutes: 10));

        combo.onVictory(); // combo=2
        advance(const Duration(minutes: 20));

        combo.onVictory(); // combo=3
        expect(combo.comboCount, 3);
        expect(combo.isComboActive, true);
      });

      test('30分経過でコンボリセット', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(
          clock: fixedClock,
          comboTimeout: const Duration(minutes: 30),
        );

        combo.onVictory();
        combo.onVictory();
        combo.onVictory();
        expect(combo.comboCount, 3);

        // 30分経過
        advance(const Duration(minutes: 31));
        expect(combo.comboCount, 0);
        expect(combo.currentMultiplier, 1.0);
        expect(combo.isComboActive, false);
      });

      test('30分経過後の討伐はコンボ1から再開', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(clock: fixedClock);

        combo.onVictory();
        combo.onVictory();
        combo.onVictory();
        expect(combo.comboCount, 3);

        advance(const Duration(minutes: 35));
        // タイムアウトを経ての討伐
        combo.onVictory();
        expect(combo.comboCount, 1); // リセットされて1から
        expect(combo.isComboActive, false); // コンボ2未満なので無効
      });

      test('カスタムタイムアウト時間を設定可能', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(
          clock: fixedClock,
          comboTimeout: const Duration(minutes: 5),
        );

        combo.onVictory();
        combo.onVictory();
        expect(combo.comboCount, 2);

        advance(const Duration(minutes: 6));
        expect(combo.comboCount, 0);
      });
    });

    group('onDefeat', () {
      test('敗北ではコンボ数は増加しない', () {
        final combo = ComboSystem(clock: fixedClock);
        combo.onVictory();
        combo.onVictory();
        expect(combo.comboCount, 2);

        combo.onDefeat();
        expect(combo.comboCount, 2); // 変わらない
      });

      test('敗北後もタイムアウトまではコンボが維持される', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(clock: fixedClock);

        combo.onVictory();
        combo.onVictory();
        combo.onVictory();
        expect(combo.comboCount, 3);

        combo.onDefeat(); // 敗北
        expect(combo.comboCount, 3); // 維持

        advance(const Duration(minutes: 20)); // まだ30分未満
        expect(combo.isComboActive, true);
        expect(combo.comboCount, 3);

        // 敗北後に再度討伐成功すればコンボは継続
        combo.onVictory();
        expect(combo.comboCount, 4);
      });
    });

    group('reset', () {
      test('コンボを強制リセット', () {
        final combo = ComboSystem(clock: fixedClock);
        combo.onVictory();
        combo.onVictory();
        combo.onVictory();
        expect(combo.comboCount, 3);

        combo.reset();
        expect(combo.comboCount, 0);
        expect(combo.currentMultiplier, 1.0);
        expect(combo.lastCombatTime, null);
        expect(combo.isComboActive, false);
      });
    });

    group('calcComboBonusExp', () {
      test('コンボ1ではボーナス0', () {
        final combo = ComboSystem(clock: fixedClock);
        combo.onVictory(); // combo=1
        expect(combo.calcComboBonusExp(100), 0);
      });

      test('コンボ数に応じたボーナスEXPを計算', () {
        final combo = ComboSystem(clock: fixedClock);
        combo.onVictory(); // combo=1
        combo.onVictory(); // combo=2, multiplier=1.1
        // bonus = 100 * (1.1 - 1.0) = 100 * 0.1 = 10
        expect(combo.calcComboBonusExp(100), 10);

        combo.onVictory(); // combo=3, multiplier=1.2
        // bonus = 100 * (1.2 - 1.0) = 20
        expect(combo.calcComboBonusExp(100), 20);
      });

      test('タイムアウト後はボーナス0', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(clock: fixedClock);

        combo.onVictory();
        combo.onVictory();
        combo.onVictory();
        expect(combo.calcComboBonusExp(100), 20);

        advance(const Duration(minutes: 31));
        expect(combo.calcComboBonusExp(100), 0);
      });
    });

    group('remainingComboTime', () {
      test('コンボ有効時の残り時間', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(clock: fixedClock);

        combo.onVictory();
        combo.onVictory();
        expect(combo.remainingComboTime.inMinutes, 30);

        advance(const Duration(minutes: 10));
        expect(combo.remainingComboTime.inMinutes, 20);
      });

      test('コンボ無効時は Duration.zero', () {
        final combo = ComboSystem(clock: fixedClock);
        expect(combo.remainingComboTime, Duration.zero);

        combo.onVictory(); // combo=1 では isComboActive=false
        expect(combo.remainingComboTime, Duration.zero);
      });
    });

    group('isComboActive', () {
      test('コンボ数2以上かつタイムアウトしていなければ true', () {
        now = DateTime(2026, 6, 7, 12, 0, 0);
        final combo = ComboSystem(clock: fixedClock);

        expect(combo.isComboActive, false);
        combo.onVictory();
        expect(combo.isComboActive, false); // combo=1 では false
        combo.onVictory();
        expect(combo.isComboActive, true); // combo=2 で true

        advance(const Duration(minutes: 31));
        expect(combo.isComboActive, false); // タイムアウト
      });
    });
  });
}
