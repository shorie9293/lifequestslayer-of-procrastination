import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/data/pomodoro_state_store.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_runtime.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _startedAt = DateTime.utc(2026, 1, 1, 9, 0, 0);

PomodoroSnapshot _runningSnapshot() => PomodoroSnapshot(
      phase: PomodoroPhase.shortBreak,
      phaseStartedAt: _startedAt,
      pausedRemaining: const Duration(minutes: 2, seconds: 30),
      completedFocusSessions: 3,
      isRunning: true,
    );

PomodoroSnapshot _pausedSnapshot() => const PomodoroSnapshot(
      phase: PomodoroPhase.focus,
      phaseStartedAt: null,
      pausedRemaining: Duration(minutes: 17, milliseconds: 250),
      completedFocusSessions: 1,
      isRunning: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesPomodoroStateStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('save→load の往復で全フィールドが一致する', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPomodoroStateStore(prefs: prefs);
      final snapshot = _runningSnapshot();

      await store.save(snapshot);
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.phase, snapshot.phase);
      expect(loaded.isRunning, snapshot.isRunning);
      expect(loaded.pausedRemaining, snapshot.pausedRemaining);
      expect(loaded.completedFocusSessions, snapshot.completedFocusSessions);
      expect(
        loaded.phaseStartedAt!.isAtSameMomentAs(snapshot.phaseStartedAt!),
        isTrue,
      );
    });

    test('paused スナップショットの往復で phaseStartedAt が null のまま', () async {
      final store = SharedPreferencesPomodoroStateStore(
        prefs: await SharedPreferences.getInstance(),
      );
      await store.save(_pausedSnapshot());
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.isRunning, isFalse);
      expect(loaded.phaseStartedAt, isNull);
      expect(loaded.pausedRemaining,
          const Duration(minutes: 17, milliseconds: 250));
    });

    test('保存前の load は null', () async {
      final store = SharedPreferencesPomodoroStateStore(
        prefs: await SharedPreferences.getInstance(),
      );
      expect(await store.load(), isNull);
    });

    test('clear 後は null になる', () async {
      final store = SharedPreferencesPomodoroStateStore(
        prefs: await SharedPreferences.getInstance(),
      );
      await store.save(_runningSnapshot());
      expect(await store.load(), isNotNull);

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('壊れた保存値（garbage）でも load は throw せず null', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pomodoro_running_state_v1': 'garbage',
      });
      final store = SharedPreferencesPomodoroStateStore(
        prefs: await SharedPreferences.getInstance(),
      );
      expect(await store.load(), isNull);
    });

    test('保存キーは pomodoro_running_state_v1', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPomodoroStateStore(prefs: prefs);
      await store.save(_runningSnapshot());
      expect(prefs.getString('pomodoro_running_state_v1'), isNotNull);
    });
  });

  group('InMemoryPomodoroStateStore', () {
    test('save→load の往復で一致する', () async {
      final store = InMemoryPomodoroStateStore();
      final snapshot = _runningSnapshot();
      await store.save(snapshot);

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.phase, snapshot.phase);
      expect(loaded.completedFocusSessions, snapshot.completedFocusSessions);
      expect(
        loaded.phaseStartedAt!.isAtSameMomentAs(snapshot.phaseStartedAt!),
        isTrue,
      );
    });

    test('初期値なしの load は null・clear で null に戻る', () async {
      final store = InMemoryPomodoroStateStore();
      expect(await store.load(), isNull);

      await store.save(_pausedSnapshot());
      expect(await store.load(), isNotNull);

      await store.clear();
      expect(await store.load(), isNull);
    });
  });
}
