/// 1回の討伐（試練との戦い）の戦績記録（改善提案 #56）。
///
/// [DefeatSummary.isVictory] は単発の成否判定のみで、履歴はどこにも残らない。
/// 本モデルは討伐の結果を不変レコードとして保持し、累積勝率・連勝記録・
/// 敗北履歴の集計（[BattleRecordService]）に供する。
///
/// 状態・IO・乱数を持たない不変モデル（値等価）。
class BattleRecord {
  /// 記録の一意識別子（重複防止・並び順タイブレークに使う）。
  final String id;

  /// 討伐対象（タスク題目）。
  final String title;

  /// 討伐が行われた日時。
  final DateTime occurredAt;

  /// 勝利なら true、敗北なら false。
  final bool isVictory;

  /// その討伐で記録したコンボ数。
  final int comboCount;

  /// 討伐終了時に残っていたサブタスク数。
  final int remainingSubTasks;

  /// 検証付きコンストラクタ（非const・本体で不変条件を強制する）。
  ///
  /// - [id]・[title] が空なら [ArgumentError]。
  /// - [comboCount]・[remainingSubTasks] が負値なら 0 へ丸める。
  /// （assert は release で無効になるため本体で検証する）
  BattleRecord({
    required this.id,
    required this.title,
    required this.occurredAt,
    required this.isVictory,
    int comboCount = 0,
    int remainingSubTasks = 0,
  })  : comboCount = comboCount < 0 ? 0 : comboCount,
        remainingSubTasks = remainingSubTasks < 0 ? 0 : remainingSubTasks {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (title.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'occurredAt': occurredAt.toIso8601String(),
        'isVictory': isVictory,
        'comboCount': comboCount,
        'remainingSubTasks': remainingSubTasks,
      };

  /// JSON から復元する。破損（キー欠落・型不一致・日時不正）は
  /// [FormatException] を投げ、呼出側（リポジトリ）が読み飛ばせるようにする。
  factory BattleRecord.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawTitle = json['title'];
    final rawOccurredAt = json['occurredAt'];
    final rawIsVictory = json['isVictory'];
    final rawCombo = json['comboCount'];
    final rawRemaining = json['remainingSubTasks'];
    if (rawId is! String ||
        rawTitle is! String ||
        rawOccurredAt is! String ||
        rawIsVictory is! bool ||
        rawCombo is! int ||
        rawRemaining is! int) {
      throw const FormatException('battle record json is malformed');
    }
    final occurredAt = DateTime.tryParse(rawOccurredAt);
    if (occurredAt == null) {
      throw const FormatException('battle record json is malformed');
    }
    return BattleRecord(
      id: rawId,
      title: rawTitle,
      occurredAt: occurredAt,
      isVictory: rawIsVictory,
      comboCount: rawCombo,
      remainingSubTasks: rawRemaining,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BattleRecord &&
      other.id == id &&
      other.title == title &&
      other.occurredAt == occurredAt &&
      other.isVictory == isVictory &&
      other.comboCount == comboCount &&
      other.remainingSubTasks == remainingSubTasks;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        occurredAt,
        isVictory,
        comboCount,
        remainingSubTasks,
      );

  @override
  String toString() =>
      'BattleRecord($id, victory=$isVictory, at=$occurredAt)';
}
