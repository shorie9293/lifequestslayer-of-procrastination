/// 勤行の日別履歴ログ（道標§五 #50）。
///
/// [Task.lastCompletedAt] は完了のたびに上書きされるため「その日に何回勤行を
/// 積んだか」という履歴が残らない。本モデルは 日付 → 完遂回数 を保持し、
/// 習慣カレンダーと成長軌跡の集計精度を高める。
///
/// 状態・IO・乱数を持たない不変モデル（値等価）。
library;

/// 1日分の勤行完遂ログ。
class PracticeLog {
  /// 対象日（年月日のみ有効・時刻は 00:00 に正規化される）。
  final DateTime date;

  /// その日の勤行完遂回数（1以上）。
  final int count;

  /// 最後に更新された日時。
  final DateTime updatedAt;

  const PracticeLog._({
    required this.date,
    required this.count,
    required this.updatedAt,
  });

  /// 検証付きファクトリ。[count] が1未満なら [ArgumentError]。
  factory PracticeLog({
    required DateTime date,
    int count = 1,
    DateTime? updatedAt,
  }) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be >= 1');
    }
    return PracticeLog._(
      date: normalizeDate(date),
      count: count,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 時刻を捨てて年月日の 00:00 に正規化する（夏時間・時刻跨ぎの影響を排除）。
  static DateTime normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 日単位の識別子（`yyyy-MM-dd`）。永続化キーとしても使う。
  String get id => keyOf(date);

  /// 日付から永続化キーを作る。
  static String keyOf(DateTime d) {
    final n = normalizeDate(d);
    final m = n.month.toString().padLeft(2, '0');
    final day = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$day';
  }

  PracticeLog copyWith({DateTime? date, int? count, DateTime? updatedAt}) {
    return PracticeLog(
      date: date ?? this.date,
      count: count ?? this.count,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'count': count,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// JSON から復元する。破損（キー欠落・型不一致・count<1）は
  /// [FormatException] を投げ、呼出側（リポジトリ）が読み飛ばせるようにする。
  factory PracticeLog.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final rawUpdated = json['updatedAt'];
    final rawCount = json['count'];
    if (rawDate is! String || rawUpdated is! String || rawCount is! int) {
      throw const FormatException('practice log json is malformed');
    }
    final date = DateTime.tryParse(rawDate);
    final updatedAt = DateTime.tryParse(rawUpdated);
    if (date == null || updatedAt == null || rawCount < 1) {
      throw const FormatException('practice log json is malformed');
    }
    return PracticeLog(date: date, count: rawCount, updatedAt: updatedAt);
  }

  String get label => '$date';

  @override
  bool operator ==(Object other) =>
      other is PracticeLog &&
      other.date == date &&
      other.count == count &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(date, count, updatedAt);

  @override
  String toString() => 'PracticeLog($id, count=$count)';
}
