import 'dart:math' as math;

import 'package:rpg_todo/domain/models/player.dart';

import 'streak_freeze_state.dart';

/// 連続記録お休み券（#153）の純粋ロジック。
///
/// すべて引数で完結する静的メソッドで、時計・リポジトリ・UI に依存しない。
/// 「7日継続するごとに1枚付与（上限3枚）」「1枚で1日分の空白を埋める」を仕様とする。
class StreakFreezeService {
  const StreakFreezeService._();

  /// 券が1枚付与される連続日数の間隔。
  static const int grantIntervalDays = 7;

  /// 保持できる券の上限（無限に貯めると連続記録の意味が失われるため）。
  static const int maxTickets = 3;

  /// 日付キー（YYYY-MM-DD、端末ローカル）。ゼロ埋め。
  static String dateKey(DateTime d) {
    final local = d.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$day';
  }

  static DateTime _dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// 前回ログイン日から今日までに「休んだ日数」（0以上）。
  ///
  /// 昨日ログイン＝0日休み（連続継続）、一昨日ログイン＝1日休み。
  static int missedDaysBetween(DateTime? last, DateTime now) {
    if (last == null) return 0;
    final diff = _dateOnly(now).difference(_dateOnly(last)).inDays;
    if (diff <= 1) return 0;
    return diff - 1;
  }

  /// 空白期間のうち「休んだ日」の日付キー（古い順）。
  static List<String> missedDateKeys(DateTime? last, DateTime now) {
    final missed = missedDaysBetween(last, now);
    if (last == null || missed <= 0) return const <String>[];
    final start = _dateOnly(last);
    return List<String>.generate(missed, (i) {
      return dateKey(DateTime(start.year, start.month, start.day + i + 1));
    }, growable: false);
  }

  /// [streakDays] までに到達した付与マイルストーン（7, 14, 21, ...）。
  static List<int> milestonesUpTo(int streakDays) {
    if (streakDays < grantIntervalDays) return const <int>[];
    final result = <int>[];
    for (var m = grantIntervalDays; m <= streakDays; m += grantIntervalDays) {
      result.add(m);
    }
    return List<int>.unmodifiable(result);
  }

  /// 到達済みで未付与のマイルストーンへ券を付与する（冪等）。
  ///
  /// 戻り値は (更新後の状態, 今回付与した枚数)。上限 [maxTickets] を超える分は
  /// 付与済みとして記録する（後から遡って二重付与しない）。
  static (StreakFreezeState, int) reconcile(
      StreakFreezeState state, int streakDays) {
    final reached = milestonesUpTo(streakDays);
    if (reached.isEmpty) return (state, 0);

    final granted = state.grantedMilestones.toSet();
    final newlyReached = reached.where((m) => !granted.contains(m)).toList();
    if (newlyReached.isEmpty) return (state, 0);

    granted.addAll(newlyReached);
    final sorted = granted.toList()..sort();
    final capacity = math.max(0, maxTickets - state.tickets);
    final add = math.min(capacity, newlyReached.length);

    return (
      state.copyWith(
        tickets: state.tickets + add,
        grantedMilestones: List<int>.unmodifiable(sorted),
      ),
      add,
    );
  }

  /// 埋めるのに必要な券の枚数（休んだ日数と同数、1枚=1日）。
  static int ticketsNeeded(int missedDays) => missedDays <= 0 ? 0 : missedDays;

  /// 保持している券で空白を埋められるか。
  static bool canCover(StreakFreezeState state, int missedDays) {
    final needed = ticketsNeeded(missedDays);
    return needed > 0 && state.tickets >= needed;
  }

  /// 券を使う。残数不足は [ArgumentError]（呼び出し側で [canCover] を先に判定する）。
  static StreakFreezeState consume(
    StreakFreezeState state, {
    required int missedDays,
    required int previousStreak,
    required DateTime now,
    List<String>? coveredDates,
  }) {
    final needed = ticketsNeeded(missedDays);
    if (needed <= 0) {
      throw ArgumentError.value(missedDays, 'missedDays', '休んだ日数がありません');
    }
    if (state.tickets < needed) {
      throw ArgumentError.value(
          state.tickets, 'tickets', 'お休み券が足りません（必要 $needed 枚）');
    }
    final usage = StreakFreezeUsage(
      usedAt: now,
      coveredMissedDays: needed,
      keptStreak: previousStreak,
      coveredDates: List<String>.unmodifiable(coveredDates ?? const <String>[]),
    );
    return state.copyWith(
      tickets: state.tickets - needed,
      history: List<StreakFreezeUsage>.unmodifiable([...state.history, usage]),
    );
  }

  /// 券を使った後のプレイヤー（連続記録を復元する）。
  ///
  /// 切断処理で 1 に落ちた streakDays を [previousStreak] + 1 へ戻す。
  /// 報酬は再計算しない（切断時に1日目分の報酬が既に付与されているため）。
  static Player restorePlayer(
    Player player, {
    required int previousStreak,
    required DateTime now,
  }) {
    final restored = previousStreak + 1;
    return player.copyWith(
      streakDays: restored,
      longestStreak: math.max(player.longestStreak, restored),
      lastLoginDate: now,
    );
  }

  /// 画面表示用の残数ラベル。
  static String ticketsLabel(StreakFreezeState state) =>
      'お休み券 ${state.tickets} / $maxTickets 枚';
}
