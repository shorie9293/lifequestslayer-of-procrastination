import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';

/// 集中の型（サムライ系ジョブスキル）— ポモドーロ集中タイマー画面。
///
/// ドメイン（Player.pomodoro系設定 / startPomodoro / isPomodoroActive /
/// JobSkill.samuraiPomodoro のEXPボーナス）は既存だが、UIが存在せず
/// 「集中の型」が実質デッド機能だったため本画面で導線を開く。
///
/// 集中フェーズが稼働している間は [PlayerViewModel.startPomodoroSession] により
/// 勤行のEXPボーナス区間（isPomodoroActive）を開き、休憩・停止時に閉じる。
class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({
    super.key,
    this.tickInterval = const Duration(seconds: 1),
  });

  /// 計時の刻み幅（試練では短い値を注入して時間を進める）。
  final Duration tickInterval;

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  PomodoroTimerState? _state;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 初回ビルド時にPlayerの設定からタイマーを構成する。
  void _ensureInitialized(PomodoroConfig config) {
    if (_state != null) return;
    _state = PomodoroTimerState.initial(config);
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.tickInterval, (_) => _onTick());
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    final current = _state;
    if (current == null || !current.isRunning) {
      _stopTicker();
      return;
    }
    setState(() {
      _state = current.tick(widget.tickInterval);
    });
    _syncPlayerPomodoro();
  }

  /// 集中フェーズ稼働中のみ Player のポモドーロ区間を開く（勤行EXPボーナス）。
  void _syncPlayerPomodoro() {
    final vm = context.read<PlayerViewModel>();
    final state = _state;
    if (state == null) return;
    final shouldBeActive = state.isRunning && state.isFocus;
    if (shouldBeActive) {
      vm.startPomodoroSession();
    } else if (vm.player.pomodoroStartTime != null) {
      vm.endPomodoroSession();
    }
  }

  void _toggleStartPause() {
    final state = _state;
    if (state == null) return;
    setState(() {
      _state = state.isRunning ? state.pause() : state.start();
    });
    if (_state!.isRunning) {
      _startTicker();
    } else {
      _stopTicker();
    }
    _syncPlayerPomodoro();
  }

  void _reset() {
    _stopTicker();
    setState(() {
      _state = _state?.reset();
    });
    context.read<PlayerViewModel>().endPomodoroSession();
  }

  void _skip() {
    final state = _state;
    if (state == null) return;
    setState(() {
      _state = state.skip();
    });
    _syncPlayerPomodoro();
  }

  @override
  Widget build(BuildContext context) {
    final playerVM = context.watch<PlayerViewModel>();
    final player = playerVM.player;
    _ensureInitialized(PomodoroConfig.fromPlayer(player));
    final state = _state!;
    final theme = Theme.of(context);
    final hasFocusSkill = player.hasSkill(JobSkill.samuraiPomodoro);
    final remainingUntilLongBreak = state.config.focusSessionsBeforeLongBreak -
        (state.completedFocusSessions % state.config.focusSessionsBeforeLongBreak);

    return Scaffold(
      key: AppKeys.pomodoroScreen,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.timer_outlined),
            SizedBox(width: 8),
            Text('集中の型'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  key: AppKeys.pomodoroPhaseLabel,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.isFocus
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.lightBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.isFocus ? Colors.amber : Colors.lightBlue,
                    ),
                  ),
                  child: Text(
                    state.phase.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: state.isFocus ? Colors.amber[800] : Colors.lightBlue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          key: AppKeys.pomodoroProgress,
                          value: state.progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.black12,
                          color: state.isFocus ? Colors.amber : Colors.lightBlue,
                        ),
                      ),
                      Text(
                        state.formattedRemaining,
                        key: AppKeys.pomodoroTime,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '完了セッション: ${state.completedFocusSessions}回 '
                '（長休止まであと$remainingUntilLongBreak回）',
                key: AppKeys.pomodoroSessionCount,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                hasFocusSkill
                    ? '集中の型（侍）: 解放済み — 集中中の勤行にEXPボーナス'
                    : '集中の型（侍）: 未解放 — 寺院で侍ジョブを伸ばすとEXPボーナス',
                key: AppKeys.pomodoroSkillStatus,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasFocusSkill ? Colors.green[700] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: AppKeys.pomodoroStartPause,
                      onPressed: _toggleStartPause,
                      icon: Icon(state.isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(state.isRunning ? '一時停止' : '開始'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: AppKeys.pomodoroReset,
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('リセット'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: AppKeys.pomodoroSkip,
                onPressed: _skip,
                icon: const Icon(Icons.skip_next),
                label: const Text('次のフェーズへ'),
              ),
              const Divider(height: 32),
              Text(
                '設定: 集中${state.config.focusMinutes}分 / '
                '小休止${state.config.shortBreakMinutes}分 / '
                '長休止${state.config.longBreakMinutes}分 '
                '（${state.config.focusSessionsBeforeLongBreak}回ごと）',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                '集中フェーズの間に勤行（クエスト）を完了すると、'
                '侍ジョブの「集中の型」EXPボーナスが発動する。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
