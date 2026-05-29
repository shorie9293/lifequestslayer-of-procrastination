import 'dart:math';
import 'package:hive/hive.dart';
import 'random_event.dart';

/// Service that checks for random town events with 15% probability.
/// Limits events to 3 per day using Hive persistence.
class RandomEventService {
  final Random _random;

  static const _probability = 0.15;
  static const _dailyLimit = 3;
  static const _boxName = 'settingsBox';
  static const _prefKey = 'town_events_count';

  RandomEventService({Random? random}) : _random = random ?? Random();

  /// Returns today's date as a string key.
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Opens the Hive settings box.
  Future<Box> _openBox() => Hive.openBox(_boxName);

  /// Returns the count of events seen today.
  Future<int> _getDailyCount(String dayKey) async {
    try {
      final box = await _openBox();
      final stored = box.get('$_prefKey.$dayKey') as String?;
      return int.tryParse(stored ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increments the daily event count.
  Future<void> _incrementDailyCount(String dayKey, int current) async {
    try {
      final box = await _openBox();
      await box.put('$_prefKey.$dayKey', '${current + 1}');
    } catch (_) {}
  }

  /// Check if a random event should occur.
  /// Returns a [RandomEvent] or null if no event occurs or daily limit reached.
  Future<RandomEvent?> checkForEvent() async {
    final dayKey = _todayKey;
    final count = await _getDailyCount(dayKey);

    if (count >= _dailyLimit) return null;
    if (_random.nextDouble() >= _probability) return null;

    await _incrementDailyCount(dayKey, count);
    return _selectEvent();
  }

  /// Picks a random event from the available event pools.
  RandomEvent _selectEvent() {
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
