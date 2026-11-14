import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';

/// ポモドーロの永続化スナップショット（不変）。
///
/// 「いつフェーズが始まったか」だけを保存し、表示すべき残り時間は
/// 復元時に実時刻との差から計算する（tick 回数に依存しない）。
@immutable
class PomodoroSnapshot {
  const PomodoroSnapshot({
    required this.phase,
    required this.phaseStartedAt,
    required this.pausedRemaining,
    required this.completedFocusSessions,
    required this.isRunning,
  });

  /// 保存フォーマットの版。
  static const int schemaVersion = 1;

  /// 現在のフェーズ。
  final PomodoroPhase phase;

  /// フェーズ開始時刻（停止中は null）。
  final DateTime? phaseStartedAt;

  /// 停止中の残り時間。
  final Duration pausedRemaining;

  /// 完了した集中セッション数。
  final int completedFocusSessions;

  /// 計時中かどうか。
  final bool isRunning;

  /// JSON 化する（例外を投げない）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'phase': phase.name,
        'phaseStartedAt': phaseStartedAt?.toUtc().toIso8601String(),
        'pausedRemainingMs': pausedRemaining.inMilliseconds,
        'completedFocusSessions': completedFocusSessions,
        'isRunning': isRunning,
        'version': schemaVersion,
      };

  /// 壊れた入力でも絶対に throw しない復元。不正なら null。
  ///
  /// [raw] は JSON 文字列でもデコード済みの Map でもよい。
  static PomodoroSnapshot? tryFromJson(Object? raw) {
    try {
      Object? decoded = raw;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return null;
        decoded = jsonDecode(decoded);
      }
      if (decoded is! Map) return null;

      final phaseKey = decoded['phase'];
      if (phaseKey is! String) return null;
      final phase = _phaseFromKey(phaseKey);
      if (phase == null) return null;

      final isRunning = decoded['isRunning'];
      if (isRunning is! bool) return null;

      final remainingMs = decoded['pausedRemainingMs'];
      if (remainingMs is! num) return null;
      if (remainingMs < 0 || remainingMs.isNaN || remainingMs.isInfinite) {
        return null;
      }

      final completed = decoded['completedFocusSessions'];
      if (completed is! num) return null;
      if (completed < 0 || completed.isNaN || completed.isInfinite) {
        return null;
      }

      DateTime? startedAt;
      final startedRaw = decoded['phaseStartedAt'];
      if (startedRaw != null) {
        if (startedRaw is! String) return null;
        startedAt = DateTime.tryParse(startedRaw);
      }

      return PomodoroSnapshot(
        phase: phase,
        phaseStartedAt: startedAt,
        pausedRemaining: Duration(milliseconds: remainingMs.toInt()),
        completedFocusSessions: completed.toInt(),
        isRunning: isRunning,
      );
    } catch (_) {
      // 型不正・パース失敗など、あらゆる異常は「状態なし」として扱う。
      return null;
    }
  }

  static PomodoroPhase? _phaseFromKey(String key) {
    for (final phase in PomodoroPhase.values) {
      if (phase.name == key) return phase;
    }
    return null;
  }

  @override
  String toString() => 'PomodoroSnapshot(phase: ${phase.name}, '
      'startedAt: $phaseStartedAt, remaining: $pausedRemaining, '
      'completed: $completedFocusSessions, running: $isRunning)';
}

/// ポモドーロの実行時計算（全て純粋・例外を投げない）。
class PomodoroRuntime {
  const PomodoroRuntime._();

  /// フェーズ送りの暴走を防ぐ上限（1年ぶんの経過でも収まる回数）。
  static const int _maxPhaseAdvances = 1000000;

  /// 保存されたスナップショットから現在の状態を復元する。
  ///
  /// 実時刻 [now] は必ず引数で受け取る（実時計に触れない）。
  static PomodoroTimerState restore({
    required PomodoroConfig config,
    required PomodoroSnapshot? snapshot,
    required DateTime now,
  }) {
    if (snapshot == null) return PomodoroTimerState.initial(config);

    final completed = snapshot.completedFocusSessions < 0
        ? 0
        : snapshot.completedFocusSessions;

    if (!snapshot.isRunning) {
      return PomodoroTimerState(
        config: config,
        phase: snapshot.phase,
        remaining: _clampRemaining(
          snapshot.pausedRemaining,
          config.durationFor(snapshot.phase),
        ),
        completedFocusSessions: completed,
        isRunning: false,
      );
    }

    final startedAt = snapshot.phaseStartedAt;
    // 開始時刻が無い稼働スナップショットは復元不能＝初期状態に落とす。
    if (startedAt == null) return PomodoroTimerState.initial(config);

    var elapsed = now.difference(startedAt);
    if (elapsed.isNegative) {
      // 時計の巻き戻り（端末時刻変更など）は「開始直後」として扱う。
      elapsed = Duration.zero;
    }

    var phase = snapshot.phase;
    var remaining = config.durationFor(phase) - elapsed;
    var completedAcc = completed;
    var advances = 0;

    while (remaining <= Duration.zero && advances < _maxPhaseAdvances) {
      advances++;
      final overflow = -remaining;
      if (phase == PomodoroPhase.focus) {
        completedAcc += 1;
      }
      phase = config.nextPhase(phase, completedAcc);
      final phaseLength = config.durationFor(phase);
      if (phaseLength <= Duration.zero) {
        // 設定異常（0分フェーズ）でも無限ループにしない。
        remaining = Duration.zero;
        break;
      }
      remaining = phaseLength - overflow;
    }

    if (remaining.isNegative) remaining = Duration.zero;

    return PomodoroTimerState(
      config: config,
      phase: phase,
      remaining: remaining,
      completedFocusSessions: completedAcc,
      isRunning: true,
    );
  }

  /// 現在の状態を保存用スナップショットに変換する。
  static PomodoroSnapshot snapshotOf({
    required PomodoroTimerState state,
    required DateTime now,
  }) {
    final remaining = _clampRemaining(state.remaining, state.phaseDuration);
    return PomodoroSnapshot(
      phase: state.phase,
      phaseStartedAt: state.isRunning
          ? now.subtract(state.phaseDuration - remaining)
          : null,
      pausedRemaining: remaining,
      completedFocusSessions:
          state.completedFocusSessions < 0 ? 0 : state.completedFocusSessions,
      isRunning: state.isRunning,
    );
  }

  /// 指定時刻での残り時間（[restore] への薄い委譲）。
  static Duration remainingAt({
    required PomodoroConfig config,
    required PomodoroSnapshot snapshot,
    required DateTime now,
  }) =>
      restore(config: config, snapshot: snapshot, now: now).remaining;

  /// 0 以上・フェーズ長以下にクランプする。
  static Duration _clampRemaining(Duration value, Duration max) {
    if (value.isNegative) return Duration.zero;
    if (max.isNegative) return Duration.zero;
    if (value > max) return max;
    return value;
  }
}
