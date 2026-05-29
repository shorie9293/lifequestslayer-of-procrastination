import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';
import 'package:rpg_todo/features/town/domain/random_event_service.dart';

void main() {
  // Initialize Hive once for all tests
  late Directory testDir;

  setUpAll(() {
    testDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(testDir.path);
  });

  tearDownAll(() {
    testDir.deleteSync(recursive: true);
  });

  // Clear settingsBox between tests
  setUp(() async {
    try {
      final box = await Hive.openBox('settingsBox');
      await box.clear();
      await box.close();
    } catch (_) {}
  });

  group('RandomEventService', () {
    test('uses 15% probability approximately', () async {
      int nullCount = 0;
      // With 15% chance, most calls return null
      for (int i = 0; i < 20; i++) {
        final service = RandomEventService(random: Random(i + 1000));
        final e = await service.checkForEvent();
        if (e == null) nullCount++;
      }
      // Expected ~17 nulls out of 20 with p=0.85
      expect(nullCount, greaterThanOrEqualTo(12));
    });

    test('returns event when random triggers', () async {
      final service = RandomEventService(random: _AlwaysLowRandom());
      final event = await service.checkForEvent();
      expect(event, isNotNull);
      expect(event, isA<RandomEvent>());
    });

    test('daily limit of 3 events', () async {
      final service = RandomEventService(random: _AlwaysLowRandom());

      for (int i = 0; i < 3; i++) {
        final event = await service.checkForEvent();
        expect(event, isNotNull, reason: 'Event $i');
      }

      final fourth = await service.checkForEvent();
      expect(fourth, isNull, reason: '4th call should hit daily limit');
    });

    test('events have correct structure', () {
      for (final e in [
        ...RandomEvent.merchantEvents,
        ...RandomEvent.bardEvents,
        ...RandomEvent.oldManEvents,
      ]) {
        expect(e.title, isNotEmpty);
        expect(e.description, isNotEmpty);
        expect(e.description.length, greaterThan(10));
        expect(e.emoji.length, lessThanOrEqualTo(4));
      }
    });
  });
}

/// Deterministic Random that always returns values triggering events.
class _AlwaysLowRandom implements Random {
  @override
  double nextDouble() => 0.1;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => true;
}
