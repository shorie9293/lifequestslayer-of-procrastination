import 'package:flutter/foundation.dart';
import 'package:rpg_todo/domain/models/player.dart';

/// 集中の型（サムライ系ジョブスキル）— ポモドーロのフェーズ。
enum PomodoroPhase {
  /// 集中時間（勤行と連動してEXPボーナスが発生する区間）
  focus,

  /// 小休止
  shortBreak,

  /// 長休止（集中N回ごと）
  longBreak,
}

extension PomodoroPhaseX on PomodoroPhase {
  /// 休憩フェーズかどうか。
  bool get isBreak => this != PomodoroPhase.focus;

  /// 日本語ラベル。
  String get label => switch (this) {
        PomodoroPhase.focus => '集中',
        PomodoroPhase.shortBreak => '小休止',
        PomodoroPhase.longBreak => '長休止',
      };
}

/// ポモドーロの設定値（Playerのフィールドから導出される不変値）。
@immutable
class PomodoroConfig {
  /// 集中時間（分）。
  final int focusMinutes;

  /// 小休止（分）。
  final int shortBreakMinutes;

  /// 長休止（分）。
  final int longBreakMinutes;

  /// 長休止に入るまでの集中セッション数。
  final int focusSessionsBeforeLongBreak;

  const PomodoroConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.focusSessionsBeforeLongBreak = 4,
  })  : assert(focusMinutes > 0),
        assert(shortBreakMinutes > 0),
        assert(longBreakMinutes > 0),
        assert(focusSessionsBeforeLongBreak > 0);

  /// Playerの設定値から構成する（寺院で変更された値をそのまま反映）。
  factory PomodoroConfig.fromPlayer(Player player) => PomodoroConfig(
        focusMinutes: player.pomodoroMinutes,
        shortBreakMinutes: player.pomodoroShortBreakMinutes,
        longBreakMinutes: player.pomodoroLongBreakMinutes,
        focusSessionsBeforeLongBreak: player.pomodorosBeforeLongBreak,
      );

  /// フェーズの長さ。
  Duration durationFor(PomodoroPhase phase) => switch (phase) {
        PomodoroPhase.focus => Duration(minutes: focusMinutes),
        PomodoroPhase.shortBreak => Duration(minutes: shortBreakMinutes),
        PomodoroPhase.longBreak => Duration(minutes: longBreakMinutes),
      };

  /// 次フェーズを返す純粋関数。
  /// [completedFocusSessions] は「完了済みの集中セッション数」で、
  /// ちょうど長休止の閾値に達したときのみ長休止を返す。
  PomodoroPhase nextPhase(PomodoroPhase current, int completedFocusSessions) {
    if (current.isBreak) return PomodoroPhase.focus;
    if (completedFocusSessions > 0 &&
        completedFocusSessions % focusSessionsBeforeLongBreak == 0) {
      return PomodoroPhase.longBreak;
    }
    return PomodoroPhase.shortBreak;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PomodoroConfig &&
          other.focusMinutes == focusMinutes &&
          other.shortBreakMinutes == shortBreakMinutes &&
          other.longBreakMinutes == longBreakMinutes &&
          other.focusSessionsBeforeLongBreak == focusSessionsBeforeLongBreak;

  @override
  int get hashCode => Object.hash(
      focusMinutes, shortBreakMinutes, longBreakMinutes, focusSessionsBeforeLongBreak);
}

/// ポモドーロタイマーの不変状態。全ての遷移は純粋関数（新しい状態を返す）。
@immutable
class PomodoroTimerState {
  /// 設定。
  final PomodoroConfig config;

  /// 現在のフェーズ。
  final PomodoroPhase phase;

  /// 現在フェーズの残り時間。
  final Duration remaining;

  /// 完了した集中セッション数。
  final int completedFocusSessions;

  /// 動作中かどうか。
  final bool isRunning;

  const PomodoroTimerState({
    required this.config,
    required this.phase,
    required this.remaining,
    this.completedFocusSessions = 0,
    this.isRunning = false,
  });

  /// 初期状態（集中フェーズ・未開始・満タン）。
  factory PomodoroTimerState.initial(PomodoroConfig config) =>
      PomodoroTimerState(
        config: config,
        phase: PomodoroPhase.focus,
        remaining: config.durationFor(PomodoroPhase.focus),
        completedFocusSessions: 0,
        isRunning: false,
      );

  /// 現在フェーズの総時間。
  Duration get phaseDuration => config.durationFor(phase);

  /// 集中フェーズかどうか。
  bool get isFocus => phase == PomodoroPhase.focus;

  /// 進捗（0.0〜1.0）。
  double get progress {
    final total = phaseDuration.inMilliseconds;
    if (total <= 0) return 1;
    final done = total - remaining.inMilliseconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// 「MM:SS」形式（端数は切り上げ。開始直後に24:59と表示させない）。
  String get formattedRemaining {
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final secs = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  PomodoroTimerState _copy({
    PomodoroPhase? phase,
    Duration? remaining,
    int? completedFocusSessions,
    bool? isRunning,
  }) =>
      PomodoroTimerState(
        config: config,
        phase: phase ?? this.phase,
        remaining: remaining ?? this.remaining,
        completedFocusSessions: completedFocusSessions ?? this.completedFocusSessions,
        isRunning: isRunning ?? this.isRunning,
      );

  /// 計時を開始する。
  PomodoroTimerState start() => isRunning ? this : _copy(isRunning: true);

  /// 計時を止める（残り時間は保持）。
  PomodoroTimerState pause() => isRunning ? _copy(isRunning: false) : this;

  /// 初期状態に戻す。
  PomodoroTimerState reset() => PomodoroTimerState.initial(config);

  /// 次フェーズへ送る（集中セッション数は数えない＝未完了として扱う）。
  PomodoroTimerState skip() {
    final next = config.nextPhase(phase, completedFocusSessions);
    return _copy(phase: next, remaining: config.durationFor(next));
  }

  /// 時間を進める。残りが0になったらフェーズを進め、あふれた分を持ち越す。
  /// 集中フェーズを満了した場合は完了セッション数を加算する。
  PomodoroTimerState tick(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', '負の経過時間は指定できない');
    }
    if (elapsed == Duration.zero) return this;

    var phaseAcc = phase;
    var remainingAcc = remaining - elapsed;
    var completedAcc = completedFocusSessions;

    // あふれが複数フェーズを跨ぐ場合もループで処理する。
    while (remainingAcc <= Duration.zero) {
      final overflow = -remainingAcc;
      if (phaseAcc == PomodoroPhase.focus) {
        completedAcc += 1;
      }
      phaseAcc = config.nextPhase(phaseAcc, completedAcc);
      remainingAcc = config.durationFor(phaseAcc) - overflow;
    }

    return _copy(phase: phaseAcc, remaining: remainingAcc, completedFocusSessions: completedAcc);
  }
}
