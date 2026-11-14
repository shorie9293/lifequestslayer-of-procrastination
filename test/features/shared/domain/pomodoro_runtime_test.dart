import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_runtime.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';

/// 実時計に一切触れない（now は必ず引数で渡す）。
const _config = PomodoroConfig();
final DateTime _t0 = DateTime.utc(2026, 1, 1, 9, 0, 0);

PomodoroSnapshot _running({
  PomodoroPhase phase = PomodoroPhase.focus,
  required DateTime startedAt,
  int completed = 0,
}) =>
    PomodoroSnapshot(
      phase: phase,
      phaseStartedAt: startedAt,
      pausedRemaining: Duration.zero,
      completedFocusSessions: completed,
      isRunning: true,
    );

void main() {
  group('PomodoroSnapshot.tryFromJson', () {
    test('null は null を返す', () {
      expect(PomodoroSnapshot.tryFromJson(null), isNull);
    });

    test('空文字は null を返す', () {
      expect(PomodoroSnapshot.tryFromJson(''), isNull);
    });

    test('JSON でない文字列は null を返す', () {
      expect(PomodoroSnapshot.tryFromJson('not json'), isNull);
    });

    test('空マップ {} は null を返す', () {
      expect(PomodoroSnapshot.tryFromJson(<String, dynamic>{}), isNull);
    });

    test('未知の phase 文字列は null を返す', () {
      expect(
        PomodoroSnapshot.tryFromJson(<String, dynamic>{
          'phase': 'nap',
          'pausedRemainingMs': 1000,
          'completedFocusSessions': 0,
          'isRunning': false,
        }),
        isNull,
      );
    });

    test('負の pausedRemainingMs は null を返す', () {
      expect(
        PomodoroSnapshot.tryFromJson(<String, dynamic>{
          'phase': 'focus',
          'pausedRemainingMs': -5,
          'completedFocusSessions': 0,
          'isRunning': false,
        }),
        isNull,
      );
    });

    test('型違い（pausedRemainingMs が文字列）は null を返す', () {
      expect(
        PomodoroSnapshot.tryFromJson(<String, dynamic>{
          'phase': 'focus',
          'pausedRemainingMs': 'abc',
          'completedFocusSessions': 0,
          'isRunning': false,
        }),
        isNull,
      );
    });

    test('型違い（isRunning が文字列）は null を返す', () {
      expect(
        PomodoroSnapshot.tryFromJson(<String, dynamic>{
          'phase': 'focus',
          'pausedRemainingMs': 1000,
          'completedFocusSessions': 0,
          'isRunning': 'yes',
        }),
        isNull,
      );
    });

    test('JSON 文字列からは復元でき、phaseStartedAt は瞬間一致する', () {
      final startedAt = _t0.subtract(const Duration(minutes: 3));
      final raw = jsonEncode(_running(startedAt: startedAt).toJson());
      final restored = PomodoroSnapshot.tryFromJson(raw);
      expect(restored, isNotNull);
      expect(restored!.phase, PomodoroPhase.focus);
      expect(restored.isRunning, isTrue);
      expect(restored.phaseStartedAt!.isAtSameMomentAs(startedAt), isTrue);
    });
  });

  group('PomodoroRuntime.restore', () {
    test('snapshot が null なら初期状態を返す', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: null,
        now: _t0,
      );
      expect(state.phase, PomodoroPhase.focus);
      expect(state.remaining, const Duration(minutes: 25));
      expect(state.completedFocusSessions, 0);
      expect(state.isRunning, isFalse);
    });

    test('時計巻き戻り（now < phaseStartedAt）でも throw せず満タンにクランプ', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(
          startedAt: _t0.add(const Duration(minutes: 10)),
        ),
        now: _t0,
      );
      expect(state.remaining, const Duration(minutes: 25));
      expect(state.phase, PomodoroPhase.focus);
      expect(state.isRunning, isTrue);
    });

    test('25分ちょうどで focus→shortBreak・completed が 1 増える', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(startedAt: _t0),
        now: _t0.add(const Duration(minutes: 25)),
      );
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.completedFocusSessions, 1);
      expect(state.remaining, const Duration(minutes: 5));
    });

    test('跨ぎ: 30分経過で shortBreak の残りが 5 分ぶん引かれている', () {
      const config = PomodoroConfig(shortBreakMinutes: 10);
      final state = PomodoroRuntime.restore(
        config: config,
        snapshot: _running(startedAt: _t0),
        now: _t0.add(const Duration(minutes: 30)),
      );
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, const Duration(minutes: 5));
      expect(state.completedFocusSessions, 1);
    });

    test('25+5+25 = 55分で completed=2・次の休憩へ送られる', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(startedAt: _t0),
        now: _t0.add(const Duration(minutes: 55)),
      );
      expect(state.completedFocusSessions, 2);
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, const Duration(minutes: 5));
    });

    test('休憩明け（60分）から4分経過で phase=focus・残り21分', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(startedAt: _t0),
        now: _t0.add(const Duration(minutes: 64)),
      );
      expect(state.phase, PomodoroPhase.focus);
      expect(state.completedFocusSessions, 2);
      expect(state.remaining, const Duration(minutes: 21));
    });

    test('長時間跨ぎ（3時間）でも正しいフェーズに落ちる', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(startedAt: _t0),
        now: _t0.add(const Duration(hours: 3)),
      );
      // 25+5+25+5+25+5+25+15 = 130 分。残り 50 分 = focus 25 + break 5 + focus 20。
      expect(state.phase, PomodoroPhase.focus);
      expect(state.completedFocusSessions, 5);
      expect(state.remaining, const Duration(minutes: 5));
      expect(state.isRunning, isTrue);
    });

    test('巨大な経過時間でも無限ループせず有限時間で返る', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(startedAt: _t0),
        now: _t0.add(const Duration(days: 365)),
      );
      expect(state.isRunning, isTrue);
      expect(state.remaining, greaterThan(Duration.zero));
      expect(
        state.remaining,
        lessThanOrEqualTo(_config.durationFor(state.phase)),
      );
    });

    test('isRunning=false なら保存された remaining をそのまま復元する', () {
      const snapshot = PomodoroSnapshot(
        phase: PomodoroPhase.shortBreak,
        phaseStartedAt: null,
        pausedRemaining: Duration(minutes: 3, seconds: 12),
        completedFocusSessions: 2,
        isRunning: false,
      );
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: snapshot,
        now: _t0,
      );
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, const Duration(minutes: 3, seconds: 12));
      expect(state.completedFocusSessions, 2);
      expect(state.isRunning, isFalse);
    });

    test('pausedRemaining が 0 なら 0 のまま', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: const PomodoroSnapshot(
          phase: PomodoroPhase.focus,
          phaseStartedAt: null,
          pausedRemaining: Duration.zero,
          completedFocusSessions: 0,
          isRunning: false,
        ),
        now: _t0,
      );
      expect(state.remaining, Duration.zero);
    });

    test('負の pausedRemaining は 0 にクランプ', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: const PomodoroSnapshot(
          phase: PomodoroPhase.focus,
          phaseStartedAt: null,
          pausedRemaining: Duration(minutes: -9),
          completedFocusSessions: 0,
          isRunning: false,
        ),
        now: _t0,
      );
      expect(state.remaining, Duration.zero);
    });

    test('フェーズ長を超える pausedRemaining は満タンにクランプ', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: const PomodoroSnapshot(
          phase: PomodoroPhase.shortBreak,
          phaseStartedAt: null,
          pausedRemaining: Duration(hours: 2),
          completedFocusSessions: 1,
          isRunning: false,
        ),
        now: _t0,
      );
      expect(state.remaining, const Duration(minutes: 5));
    });

    test('isRunning=true だが phaseStartedAt が null なら初期状態', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: const PomodoroSnapshot(
          phase: PomodoroPhase.longBreak,
          phaseStartedAt: null,
          pausedRemaining: Duration(minutes: 4),
          completedFocusSessions: 4,
          isRunning: true,
        ),
        now: _t0,
      );
      expect(state.phase, PomodoroPhase.focus);
      expect(state.remaining, const Duration(minutes: 25));
      expect(state.completedFocusSessions, 0);
      expect(state.isRunning, isFalse);
    });

    test('負の completedFocusSessions は 0 にクランプ', () {
      final state = PomodoroRuntime.restore(
        config: _config,
        snapshot: _running(startedAt: _t0, completed: -3),
        now: _t0.add(const Duration(minutes: 1)),
      );
      expect(state.completedFocusSessions, greaterThanOrEqualTo(0));
    });
  });

  group('PomodoroRuntime.snapshotOf', () {
    test('running 状態では開始時刻を残量から逆算する', () {
      const state = PomodoroTimerState(
        config: _config,
        phase: PomodoroPhase.focus,
        remaining: Duration(minutes: 10),
        isRunning: true,
      );
      final snapshot = PomodoroRuntime.snapshotOf(state: state, now: _t0);
      expect(snapshot.isRunning, isTrue);
      expect(snapshot.pausedRemaining, const Duration(minutes: 10));
      expect(
        snapshot.phaseStartedAt!.isAtSameMomentAs(
          _t0.subtract(const Duration(minutes: 15)),
        ),
        isTrue,
      );
    });

    test('paused 状態では phaseStartedAt が null', () {
      const state = PomodoroTimerState(
        config: _config,
        phase: PomodoroPhase.focus,
        remaining: Duration(minutes: 10),
      );
      final snapshot = PomodoroRuntime.snapshotOf(state: state, now: _t0);
      expect(snapshot.isRunning, isFalse);
      expect(snapshot.phaseStartedAt, isNull);
      expect(snapshot.pausedRemaining, const Duration(minutes: 10));
    });

    test('running の snapshotOf→restore 往復で remaining が一致する', () {
      const state = PomodoroTimerState(
        config: _config,
        phase: PomodoroPhase.shortBreak,
        remaining: Duration(minutes: 2, seconds: 30),
        completedFocusSessions: 1,
        isRunning: true,
      );
      final snapshot = PomodoroRuntime.snapshotOf(state: state, now: _t0);
      final restored = PomodoroRuntime.restore(
          config: _config, snapshot: snapshot, now: _t0);
      expect(restored.remaining, state.remaining);
      expect(restored.phase, state.phase);
      expect(restored.completedFocusSessions, state.completedFocusSessions);
      expect(restored.isRunning, isTrue);
    });

    test('paused の snapshotOf→restore 往復で remaining が一致する', () {
      const state = PomodoroTimerState(
        config: _config,
        phase: PomodoroPhase.focus,
        remaining: Duration(minutes: 7, seconds: 45),
        completedFocusSessions: 3,
      );
      final snapshot = PomodoroRuntime.snapshotOf(state: state, now: _t0);
      final restored = PomodoroRuntime.restore(
          config: _config, snapshot: snapshot, now: _t0);
      expect(restored.remaining, state.remaining);
      expect(restored.completedFocusSessions, 3);
      expect(restored.isRunning, isFalse);
    });
  });

  group('PomodoroRuntime.remainingAt', () {
    test('restore(...).remaining と一致する', () {
      final snapshot = _running(startedAt: _t0);
      final now = _t0.add(const Duration(minutes: 12));
      final viaRestore = PomodoroRuntime.restore(
          config: _config, snapshot: snapshot, now: now);
      expect(
        PomodoroRuntime.remainingAt(
            config: _config, snapshot: snapshot, now: now),
        viaRestore.remaining,
      );
    });

    test('now を引数で変えると残りも変わる（実時計に触れない）', () {
      final snapshot = _running(startedAt: _t0);
      final early = PomodoroRuntime.remainingAt(
        config: _config,
        snapshot: snapshot,
        now: _t0.add(const Duration(minutes: 5)),
      );
      final late = PomodoroRuntime.remainingAt(
        config: _config,
        snapshot: snapshot,
        now: _t0.add(const Duration(minutes: 15)),
      );
      expect(early, const Duration(minutes: 20));
      expect(late, const Duration(minutes: 10));
    });
  });
}
