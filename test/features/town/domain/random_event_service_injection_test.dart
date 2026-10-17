import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/town/data/random_event_store.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';
import 'package:rpg_todo/features/town/domain/random_event_service.dart';

/// 指定値を返す Random（確率境界を厳密に撃つため）。
class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('注入した store と clock', () {
    test('1日3回まで（4回目は抽選を通さない）', () async {
      final store = InMemoryRandomEventStore();
      final service = RandomEventService(
        random: _FixedRandom(0.0),
        store: store,
        clock: () => DateTime(2026, 10, 17, 12),
      );

      for (var i = 0; i < 3; i++) {
        expect(await service.checkForEvent(), isNotNull, reason: 'event $i');
      }
      expect(await service.checkForEvent(), isNull);
      expect(await service.dailyCount(), 3);
      expect(await service.remainingToday(), 0);
      expect(store.counts[RandomEventService.dayKeyOf(DateTime(2026, 10, 17))],
          3);
    });

    test('日が変われば回数はリセットされる（実時計を直読みしない）', () async {
      final store = InMemoryRandomEventStore();
      var now = DateTime(2026, 10, 17, 23, 55);
      final service = RandomEventService(
        random: _FixedRandom(0.0),
        store: store,
        clock: () => now,
      );

      for (var i = 0; i < 3; i++) {
        await service.checkForEvent();
      }
      expect(await service.checkForEvent(), isNull);

      // 暦を進める（固定時計ゆえ試練が将来赤化しない）
      now = DateTime(2026, 10, 18, 0, 5);
      expect(await service.checkForEvent(), isNotNull);
      expect(await service.dailyCount(), 1);
    });

    test('確率境界: 0.15 未満で発生・0.15 以上で発生しない', () async {
      final low = RandomEventService(
        random: _FixedRandom(0.149999),
        store: InMemoryRandomEventStore(),
        clock: () => DateTime(2026, 10, 17),
      );
      expect(await low.checkForEvent(), isNotNull);

      final boundary = RandomEventService(
        random: _FixedRandom(0.15),
        store: InMemoryRandomEventStore(),
        clock: () => DateTime(2026, 10, 17),
      );
      expect(await boundary.checkForEvent(), isNull);
    });

    test('抽選に漏れた回はカウントを消費しない', () async {
      final store = InMemoryRandomEventStore();
      final service = RandomEventService(
        random: _FixedRandom(0.9),
        store: store,
        clock: () => DateTime(2026, 10, 17),
      );
      for (var i = 0; i < 5; i++) {
        expect(await service.checkForEvent(), isNull);
      }
      expect(await service.dailyCount(), 0);
      expect(store.counts, isEmpty);
    });

    test('生成されたイベントは3プールのいずれかに属する', () async {
      final service = RandomEventService(
        random: _FixedRandom(0.0),
        store: InMemoryRandomEventStore(),
        clock: () => DateTime(2026, 10, 17),
      );
      final event = await service.checkForEvent();
      expect(event, isNotNull);
      final all = [
        ...RandomEvent.merchantEvents,
        ...RandomEvent.bardEvents,
        ...RandomEvent.oldManEvents,
      ];
      expect(all.contains(event), isTrue);
    });

    test('dayKeyOf は月日をゼロ埋めしない既存仕様を保つ', () {
      expect(RandomEventService.dayKeyOf(DateTime(2026, 1, 5)), '2026-1-5');
    });
  });
}
