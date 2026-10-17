import 'dart:math';

import 'package:rpg_todo/features/town/data/random_event_store.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';

/// Service that checks for random town events with 15% probability.
/// Limits events to 3 per day using [RandomEventStore] persistence.
///
/// - [random] を注入すれば確率境界を固定シードで撃てる。
/// - [clock] を注入すれば暦が進んでも試練が赤化しない
///   （`DateTime.now()` 直読みは「暦が進むと落ちる時限爆弾」になる）。
/// - [store] を注入すれば Hive 未初期化環境（widget 試練）でも安全に動く。
class RandomEventService {
  final Random _random;
  final RandomEventStore _store;
  final DateTime Function() _clock;

  static const double probability = 0.15;
  static const int dailyLimit = 3;

  RandomEventService({
    Random? random,
    RandomEventStore? store,
    DateTime Function()? clock,
  })  : _random = random ?? Random(),
        _store = store ?? HiveRandomEventStore(),
        _clock = clock ?? DateTime.now;

  /// 日付キー（`YYYY-M-D`）。日跨ぎのリセット判定に用いる。
  static String dayKeyOf(DateTime dateTime) =>
      '${dateTime.year}-${dateTime.month}-${dateTime.day}';

  /// 今日の日付キー。
  String get todayKey => dayKeyOf(_clock());

  /// 今日すでに遭遇したイベント数。
  Future<int> dailyCount() => _store.readCount(todayKey);

  /// 今日あと何回イベントに出会えるか。
  Future<int> remainingToday() async {
    final count = await _store.readCount(todayKey);
    final remaining = dailyLimit - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check if a random event should occur.
  /// Returns a [RandomEvent] or null if no event occurs or daily limit reached.
  Future<RandomEvent?> checkForEvent() async {
    final dayKey = todayKey;
    final count = await _store.readCount(dayKey);

    if (count >= dailyLimit) return null;
    if (_random.nextDouble() >= probability) return null;

    await _store.writeCount(dayKey, count + 1);
    return selectEvent();
  }

  /// Picks a random event from the available event pools.
  RandomEvent selectEvent() {
    // Weighted: merchant 40%, bard 35%, old man 25%
    final roll = _random.nextDouble();
    final List<RandomEvent> pool;
    if (roll < 0.40) {
      pool = RandomEvent.merchantEvents;
    } else if (roll < 0.75) {
      pool = RandomEvent.bardEvents;
    } else {
      pool = RandomEvent.oldManEvents;
    }
    return pool[_random.nextInt(pool.length)];
  }
}
