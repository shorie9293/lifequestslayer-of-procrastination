import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/pomodoro_state_store.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_runtime.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';

/// 集中の型（サムライ系ジョブスキル）— ポモドーロ集中タイマー画面。
///
/// ドメイン（Player.pomodoro系設定 / startPomodoro / isPomodoroActive /
/// JobSkill.samuraiPomodoro のEXPボーナス）は既存だが、UIが存在せず
/// 「集中の型」が実質デッド機能だったため本画面で導線を開く。
///
/// 集中フェーズが稼働している間は [PlayerViewModel.startPomodoroSession] により
/// 勤行のEXPボーナス区間（isPomodoroActive）を開き、休憩・停止時に閉じる。
///
/// 計時は「tick の積算」ではなく**実時間差（開始時刻＋now）**で行う。
/// tick は再描画のきっかけに過ぎず、走行状態は [PomodoroStateStore] に
/// 永続化されるため、画面離脱・再入場・アプリ再起動を跨いで計測が続く。
class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({
    super.key,
    this.tickInterval = const Duration(seconds: 1),
    this.now = DateTime.now,
    this.store,
  });

  /// 再描画のきっかけとなる刻み幅（試練では短い値を注入して描画を進める）。
  final Duration tickInterval;

  /// 現在時刻の供給元（試練では偽時計を注入する）。
  final DateTime Function() now;

  /// 走行状態の保存先（null なら SharedPreferences 実装を内部生成）。
  final PomodoroStateStore? store;

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen>
    with WidgetsBindingObserver {
  PomodoroTimerState? _state;
  Timer? _timer;

  /// 走行中フェーズの開始時刻（走行開始時に一度だけ確定し、tick毎に再逆算しない）。
  DateTime? _anchor;

  /// Player 側のポモドーロ区間が開いているか（遷移時のみ呼ぶためのキャッシュ）。
  bool _playerSessionOpen = false;

  late final PomodoroStateStore _store;
  late final PlayerViewModel _playerVM;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = widget.store ?? SharedPreferencesPomodoroStateStore();
    _playerVM = context.read<PlayerViewModel>();
    unawaited(_restoreFromStore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// 保存済みの走行状態から復元する（失敗しても初期状態で起動する）。
  Future<void> _restoreFromStore() async {
    final config = PomodoroConfig.fromPlayer(_playerVM.player);
    PomodoroSnapshot? snapshot;
    try {
      snapshot = await _store.load();
    } catch (_) {
      snapshot = null;
    }
    if (!mounted) return;

    final now = widget.now();
    final restored = _guard(
      () => PomodoroRuntime.restore(
        config: config,
        snapshot: snapshot,
        now: now,
      ),
      fallback: () => PomodoroTimerState.initial(config),
    );

    setState(() {
      _state = restored;
      _anchor = restored.isRunning ? (snapshot?.phaseStartedAt ?? now) : null;
    });

    if (restored.isRunning) _startTicker();
    _syncPlayerPomodoro();
  }

  /// 例外を投げない計算の保険（純粋層が壊れていても画面を落とさない）。
  T _guard<T>(T Function() body, {required T Function() fallback}) {
    try {
      return body();
    } catch (_) {
      return fallback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンド復帰時は実時間差ぶん進める（tick は止まっているため）。
    if (state == AppLifecycleState.resumed) {
      _refreshFromClock();
    }
  }

  /// 実時間差で状態を再計算して描画する。
  void _refreshFromClock() {
    final current = _state;
    if (current == null || !current.isRunning) return;
    final now = widget.now();
    final next = _recompute(now);
    setState(() {
      _state = next;
    });
    _applyAnchor(next, now);
    if (!next.isRunning) _stopTicker();
    if (next.phase != current.phase ||
        next.completedFocusSessions != current.completedFocusSessions ||
        !next.isRunning) {
      _persist();
    }
    _syncPlayerPomodoro();
  }

  /// 初回ビルド時にPlayerの設定からタイマーを構成する（復元前の暫定表示）。
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

  /// tick は「描画のきっかけ」専用。時間は実時間差から算出する。
  void _onTick() {
    final current = _state;
    if (current == null || !current.isRunning) {
      _stopTicker();
      return;
    }
    final now = widget.now();
    final next = _recompute(now);
    setState(() {
      _state = next;
    });
    _applyAnchor(next, now);
    if (!next.isRunning) _stopTicker();
    if (next.phase != current.phase ||
        next.completedFocusSessions != current.completedFocusSessions) {
      _persist();
    }
    _syncPlayerPomodoro();
  }

  /// 確定済みの開始時刻 [anchor] と実時刻から現在状態を求める。
  PomodoroTimerState _recompute(DateTime now) {
    final current = _state!;
    final anchor = _anchor;
    if (!current.isRunning || anchor == null) return current;
    final snapshot = PomodoroSnapshot(
      phase: current.phase,
      phaseStartedAt: anchor,
      pausedRemaining: current.remaining,
      completedFocusSessions: current.completedFocusSessions,
      isRunning: true,
    );
    return _guard(
      () => PomodoroRuntime.restore(
        config: current.config,
        snapshot: snapshot,
        now: now,
      ),
      fallback: () => current,
    );
  }

  /// 再計算後もドリフトしないよう、フェーズ開始時刻を実時刻から逆算して更新する。
  void _applyAnchor(PomodoroTimerState state, DateTime now) {
    if (!state.isRunning) {
      _anchor = null;
      return;
    }
    final into = state.phaseDuration - state.remaining;
    _anchor = now.subtract(into.isNegative ? Duration.zero : into);
  }

  /// 現在状態を保存する（例外は握りつぶす）。
  void _persist() {
    final state = _state;
    if (state == null) return;
    final now = widget.now();
    late final PomodoroSnapshot snapshot;
    if (state.isRunning) {
      snapshot = PomodoroSnapshot(
        phase: state.phase,
        phaseStartedAt: _anchor ?? now,
        pausedRemaining: state.remaining,
        completedFocusSessions: state.completedFocusSessions,
        isRunning: true,
      );
    } else {
      snapshot = PomodoroRuntime.snapshotOf(state: state, now: now);
    }
    unawaited(_store.save(snapshot));
  }

  /// 集中フェーズ稼働中のみ Player のポモドーロ区間を開く（勤行EXPボーナス）。
  ///
  /// 毎tick呼ぶと無駄な保存が走るため、区間の開閉が変化した時のみ実行する。
  void _syncPlayerPomodoro() {
    final state = _state;
    if (state == null) return;
    final shouldBeActive = state.isRunning && state.isFocus;
    if (shouldBeActive == _playerSessionOpen) return;
    _playerSessionOpen = shouldBeActive;
    if (shouldBeActive) {
      _playerVM.startPomodoroSession();
    } else {
      _playerVM.endPomodoroSession();
    }
  }

  void _toggleStartPause() {
    final state = _state;
    if (state == null) return;
    final now = widget.now();
    if (state.isRunning) {
      setState(() {
        _state = state.pause();
        _anchor = null;
      });
      _stopTicker();
    } else {
      setState(() {
        _state = state.start();
        _anchor = now;
      });
      _startTicker();
    }
    _persist();
    _syncPlayerPomodoro();
  }

  void _reset() {
    _stopTicker();
    setState(() {
      _state = _state?.reset();
      _anchor = null;
    });
    unawaited(_store.clear());
    _playerSessionOpen = false;
    _playerVM.endPomodoroSession();
  }

  void _skip() {
    final state = _state;
    if (state == null) return;
    final now = widget.now();
    setState(() {
      _state = state.skip();
      _anchor = _state!.isRunning ? now : null;
    });
    _persist();
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
        (state.completedFocusSessions %
            state.config.focusSessionsBeforeLongBreak);

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      color: state.isFocus
                          ? Colors.amber[800]
                          : Colors.lightBlue[800],
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
                          color:
                              state.isFocus ? Colors.amber : Colors.lightBlue,
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
                      icon: Icon(
                          state.isRunning ? Icons.pause : Icons.play_arrow),
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                '集中フェーズの間に勤行（クエスト）を完了すると、'
                '侍ジョブの「集中の型」EXPボーナスが発動する。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
