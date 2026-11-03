import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/lock_reload_policy.dart';

void main() {
  final bg = DateTime(2026, 1, 1, 9, 0, 0);

  group('LockReloadPolicy.shouldRelock', () {
    test('背景化を観測していなければ再施錠する', () {
      expect(
        LockReloadPolicy.shouldRelock(
          null,
          bg.add(const Duration(hours: 1)),
          const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('猶予0は即時に再施錠する', () {
      expect(
        LockReloadPolicy.shouldRelock(bg, bg, Duration.zero),
        isTrue,
      );
      expect(
        LockReloadPolicy.shouldRelock(
          bg,
          bg.add(const Duration(milliseconds: 1)),
          Duration.zero,
        ),
        isTrue,
      );
    });

    test('猶予内の復帰は再施錠しない', () {
      expect(
        LockReloadPolicy.shouldRelock(
          bg,
          bg.add(const Duration(seconds: 29)),
          const Duration(seconds: 30),
        ),
        isFalse,
      );
    });

    test('境界ちょうどは再施錠する', () {
      expect(
        LockReloadPolicy.shouldRelock(
          bg,
          bg.add(const Duration(seconds: 30)),
          const Duration(seconds: 30),
        ),
        isTrue,
      );
    });

    test('猶予超過は再施錠する', () {
      expect(
        LockReloadPolicy.shouldRelock(
          bg,
          bg.add(const Duration(seconds: 31)),
          const Duration(seconds: 30),
        ),
        isTrue,
      );
    });

    test('時計巻き戻しは安全側（再施錠）に倒す', () {
      expect(
        LockReloadPolicy.shouldRelock(
          bg,
          bg.subtract(const Duration(seconds: 1)),
          const Duration(minutes: 5),
        ),
        isTrue,
      );
    });
  });

  group('LockReloadPolicy.graceLabel', () {
    test('既知の選択肢は読みやすいラベルになる', () {
      expect(LockReloadPolicy.graceLabel(0), '即時');
      expect(LockReloadPolicy.graceLabel(30), '30秒');
      expect(LockReloadPolicy.graceLabel(60), '1分');
      expect(LockReloadPolicy.graceLabel(300), '5分');
    });

    test('未知の値は秒表記にフォールバックする', () {
      expect(LockReloadPolicy.graceLabel(45), '45秒');
      expect(LockReloadPolicy.graceLabel(1), '1秒');
    });

    test('選択肢は 0/30/60/300 を昇順で持つ', () {
      expect(LockReloadPolicy.graceOptionsSeconds, [0, 30, 60, 300]);
    });
  });
}
