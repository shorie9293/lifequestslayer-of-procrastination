/// ストリークお休み券（#153）の永続状態。
///
/// 「1日休んでも連続記録を維持できる券」の残数・付与済みマイルストーン・
/// 使用履歴を保持する。旧データ（本フィールドが無い JSON）は既定値で読める。
library;

/// お休み券の使用履歴1件。
class StreakFreezeUsage {
  /// 使用した日時（端末ローカル）。
  final DateTime usedAt;

  /// この券で埋めた「休んだ日数」（1枚=1日）。
  final int coveredMissedDays;

  /// 使用前の連続日数（この日数を守った）。
  final int keptStreak;

  /// 埋めた空白日（休んだ日）の日付キー（YYYY-MM-DD）。古い順。
  final List<String> coveredDates;

  const StreakFreezeUsage({
    required this.usedAt,
    required this.coveredMissedDays,
    required this.keptStreak,
    this.coveredDates = const <String>[],
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'usedAt': usedAt.toIso8601String(),
        'coveredMissedDays': coveredMissedDays,
        'keptStreak': keptStreak,
        'coveredDates': coveredDates,
      };

  /// 破損 JSON は null を返し、呼び出し側で読み飛ばす。
  static StreakFreezeUsage? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final usedAtRaw = raw['usedAt'];
    final usedAt = usedAtRaw is String ? DateTime.tryParse(usedAtRaw) : null;
    if (usedAt == null) return null;
    final covered = raw['coveredMissedDays'];
    final kept = raw['keptStreak'];
    final dates = raw['coveredDates'];
    return StreakFreezeUsage(
      usedAt: usedAt,
      coveredMissedDays: covered is int && covered > 0 ? covered : 1,
      keptStreak: kept is int && kept > 0 ? kept : 0,
      coveredDates: dates is List
          ? List<String>.unmodifiable(
              dates.whereType<String>().toList(growable: false))
          : const <String>[],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StreakFreezeUsage &&
      other.usedAt == usedAt &&
      other.coveredMissedDays == coveredMissedDays &&
      other.keptStreak == keptStreak &&
      _listEquals(other.coveredDates, coveredDates);

  @override
  int get hashCode => Object.hash(
      usedAt, coveredMissedDays, keptStreak, Object.hashAll(coveredDates));

  @override
  String toString() =>
      'StreakFreezeUsage(usedAt: $usedAt, covered: $coveredMissedDays, kept: $keptStreak)';
}

/// お休み券の残数・付与履歴（マイルストーン）・使用履歴。
class StreakFreezeState {
  /// 現在の残数。
  final int tickets;

  /// 既に付与済みのマイルストーン日数（例: 7, 14, 21）。二重付与を防ぐ。
  final List<int> grantedMilestones;

  /// 使用履歴（古い順）。
  final List<StreakFreezeUsage> history;

  const StreakFreezeState({
    this.tickets = 0,
    this.grantedMilestones = const <int>[],
    this.history = const <StreakFreezeUsage>[],
  });

  /// 旧データ・破損時の既定値（残数0＝券なし）。
  static const StreakFreezeState defaults = StreakFreezeState();

  StreakFreezeState copyWith({
    int? tickets,
    List<int>? grantedMilestones,
    List<StreakFreezeUsage>? history,
  }) =>
      StreakFreezeState(
        tickets: tickets ?? this.tickets,
        grantedMilestones: grantedMilestones ?? this.grantedMilestones,
        history: history ?? this.history,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tickets': tickets,
        'grantedMilestones': grantedMilestones,
        'history': history.map((h) => h.toJson()).toList(growable: false),
      };

  /// 破損・型不一致は既定値へフォールバックする（例外を投げない）。
  static StreakFreezeState fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final ticketsRaw = raw['tickets'];
    final milestonesRaw = raw['grantedMilestones'];
    final historyRaw = raw['history'];
    final tickets = ticketsRaw is int && ticketsRaw > 0 ? ticketsRaw : 0;
    final milestones = milestonesRaw is List
        ? List<int>.unmodifiable(
            milestonesRaw.whereType<int>().where((m) => m > 0))
        : const <int>[];
    final history = <StreakFreezeUsage>[];
    if (historyRaw is List) {
      for (final entry in historyRaw) {
        final parsed = StreakFreezeUsage.tryFromJson(entry);
        if (parsed != null) history.add(parsed);
      }
    }
    return StreakFreezeState(
      tickets: tickets,
      grantedMilestones: milestones,
      history: List<StreakFreezeUsage>.unmodifiable(history),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StreakFreezeState &&
      other.tickets == tickets &&
      _listEquals(other.grantedMilestones, grantedMilestones) &&
      _listEquals(other.history, history);

  @override
  int get hashCode =>
      Object.hash(tickets, Object.hashAll(grantedMilestones), Object.hashAll(history));

  @override
  String toString() =>
      'StreakFreezeState(tickets: $tickets, granted: $grantedMilestones, history: ${history.length})';
}

/// お休み券の使用提案（切断が起きた直後に提示する）。
///
/// ログイン時のストリーク更新で切断された場合にのみ生成され、
/// 画面で「使う」を押した時に [Player] が復元される。
class StreakFreezeOffer {
  /// 切断前の連続日数。
  final int previousStreak;

  /// 休んだ日数（1枚=1日）。
  final int missedDays;

  /// 休んだ日の日付キー（古い順）。
  final List<String> missedDateKeys;

  const StreakFreezeOffer({
    required this.previousStreak,
    required this.missedDays,
    this.missedDateKeys = const <String>[],
  });

  @override
  bool operator ==(Object other) =>
      other is StreakFreezeOffer &&
      other.previousStreak == previousStreak &&
      other.missedDays == missedDays &&
      _listEquals(other.missedDateKeys, missedDateKeys);

  @override
  int get hashCode =>
      Object.hash(previousStreak, missedDays, Object.hashAll(missedDateKeys));

  @override
  String toString() =>
      'StreakFreezeOffer(previousStreak: $previousStreak, missedDays: $missedDays)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
