import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';

void main() {
  group('PomodoroConfig', () {
    test('fromPlayer reads the player settings', () {
      final player = Player(
        pomodoroMinutes: 30,
        pomodoroShortBreakMinutes: 6,
        pomodoroLongBreakMinutes: 20,
        pomodorosBeforeLongBreak: 3,
      );
      final config = PomodoroConfig.fromPlayer(player);
      expect(config.focusMinutes, 30);
      expect(config.shortBreakMinutes, 6);
      expect(config.longBreakMinutes, 20);
      expect(config.focusSessionsBeforeLongBreak, 3);
    });

    test('durationFor maps each phase', () {
      const config = PomodoroConfig();
      expect(config.durationFor(PomodoroPhase.focus), const Duration(minutes: 25));
      expect(config.durationFor(PomodoroPhase.shortBreak), const Duration(minutes: 5));
      expect(config.durationFor(PomodoroPhase.longBreak), const Duration(minutes: 15));
    });

    test('nextPhase returns shortBreak until the long break threshold', () {
      const config = PomodoroConfig(focusSessionsBeforeLongBreak: 4);
      expect(config.nextPhase(PomodoroPhase.focus, 1), PomodoroPhase.shortBreak);
      expect(config.nextPhase(PomodoroPhase.focus, 3), PomodoroPhase.shortBreak);
      expect(config.nextPhase(PomodoroPhase.focus, 4), PomodoroPhase.longBreak);
      expect(config.nextPhase(PomodoroPhase.focus, 8), PomodoroPhase.longBreak);
    });

    test('nextPhase from any break returns focus', () {
      const config = PomodoroConfig();
      expect(config.nextPhase(PomodoroPhase.shortBreak, 1), PomodoroPhase.focus);
      expect(config.nextPhase(PomodoroPhase.longBreak, 4), PomodoroPhase.focus);
    });

    test('equality is value based', () {
      expect(const PomodoroConfig(), const PomodoroConfig());
      expect(const PomodoroConfig(focusMinutes: 10), isNot(const PomodoroConfig()));
    });
  });

  group('PomodoroTimerState — 初期状態', () {
    test('initial state is focus, full time, not running', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      expect(state.phase, PomodoroPhase.focus);
      expect(state.remaining, const Duration(minutes: 25));
      expect(state.isRunning, isFalse);
      expect(state.completedFocusSessions, 0);
      expect(state.isFocus, isTrue);
    });

    test('formattedRemaining shows MM:SS without dropping a second', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      expect(state.formattedRemaining, '25:00');
    });

    test('progress starts at 0 and reaches 1 at the end of the phase', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      expect(state.progress, 0.0);
      expect(state.tick(const Duration(seconds: 750)).progress, closeTo(0.5, 0.001));
      expect(state.tick(const Duration(minutes: 25)).reset().progress, 0.0);
    });
  });

  group('PomodoroTimerState — 計時', () {
    test('start sets running, pause clears it', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      final running = state.start();
      expect(running.isRunning, isTrue);
      expect(running.pause().isRunning, isFalse);
    });

    test('tick does not move while paused is irrelevant — tick always advances', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      final after = state.tick(const Duration(minutes: 1));
      expect(after.remaining, const Duration(minutes: 24));
      expect(after.formattedRemaining, '24:00');
    });

    test('tick with zero duration returns the same values', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      final after = state.tick(Duration.zero);
      expect(after.remaining, state.remaining);
      expect(after.completedFocusSessions, 0);
    });

    test('tick with negative duration throws ArgumentError', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      expect(() => state.tick(const Duration(seconds: -1)), throwsArgumentError);
    });

    test('completing a focus session advances to short break and counts it', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      final after = state.tick(const Duration(minutes: 25));
      expect(after.phase, PomodoroPhase.shortBreak);
      expect(after.remaining, const Duration(minutes: 5));
      expect(after.completedFocusSessions, 1);
    });

    test('completing the 4th focus session advances to a long break', () {
      var state = PomodoroTimerState.initial(const PomodoroConfig());
      for (var i = 0; i < 3; i++) {
        state = state.tick(const Duration(minutes: 30)); // 25集中 + 5小休止
      }
      expect(state.phase, PomodoroPhase.focus);
      expect(state.completedFocusSessions, 3);
      state = state.tick(const Duration(minutes: 25)); // 4回目
      expect(state.phase, PomodoroPhase.longBreak);
      expect(state.remaining, const Duration(minutes: 15));
      expect(state.completedFocusSessions, 4);
    });

    test('completing a break returns to focus without counting', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig())
          .tick(const Duration(minutes: 25))
          .tick(const Duration(minutes: 5));
      expect(state.phase, PomodoroPhase.focus);
      expect(state.completedFocusSessions, 1);
      expect(state.remaining, const Duration(minutes: 25));
    });

    test('overflow carries into the next phase', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig())
          .tick(const Duration(minutes: 27));
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, const Duration(minutes: 3));
    });

    test('a long elapsed time rolls through multiple phases', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig())
          .tick(const Duration(minutes: 32)); // 25集中 + 5小休止 + 2集中
      expect(state.completedFocusSessions, 1);
      expect(state.phase, PomodoroPhase.focus);
      expect(state.remaining, const Duration(minutes: 23));
    });

    test('skip advances without counting the focus session', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig());
      final skipped = state.skip();
      expect(skipped.phase, PomodoroPhase.shortBreak);
      expect(skipped.completedFocusSessions, 0);
      expect(skipped.remaining, const Duration(minutes: 5));
      expect(skipped.skip().phase, PomodoroPhase.focus);
    });

    test('reset returns to the initial state', () {
      final state = PomodoroTimerState.initial(const PomodoroConfig())
          .start()
          .tick(const Duration(minutes: 10));
      final reset = state.reset();
      expect(reset.phase, PomodoroPhase.focus);
      expect(reset.remaining, const Duration(minutes: 25));
      expect(reset.completedFocusSessions, 0);
      expect(reset.isRunning, isFalse);
    });
  });

  group('PomodoroTimerState — 勤行連動', () {
    test('focus phase duration matches Player.pomodoroMinutes', () {
      final player = Player(pomodoroMinutes: 50);
      final state = PomodoroTimerState.initial(PomodoroConfig.fromPlayer(player));
      expect(state.phaseDuration, const Duration(minutes: 50));
      // 50分以内なら isPomodoroActive が true になること（EXPボーナス前提）
      final started = player.startPomodoro();
      expect(started.isPomodoroActive, isTrue);
    });

    test('phase labels are Japanese', () {
      expect(PomodoroPhase.focus.label, '集中');
      expect(PomodoroPhase.shortBreak.label, '小休止');
      expect(PomodoroPhase.longBreak.label, '長休止');
      expect(PomodoroPhase.focus.isBreak, isFalse);
      expect(PomodoroPhase.longBreak.isBreak, isTrue);
    });
  });
}
