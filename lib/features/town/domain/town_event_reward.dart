/// 町のランダムイベントが与える報酬を型付きで表す純粋モデル。
///
/// `RandomEvent.reward` は自由形式の `Map<String, dynamic>?` であり、
/// 画面側が直接キーを読むと表記揺れ・型揺れ（int/String/num/null）で
/// 静かに報酬を取りこぼす。本モデルを唯一の解釈点とする。
class TownEventReward {
  /// 獲得経験値（負値・非数値は 0 に丸める）。
  final int xp;

  /// 獲得ジェム（負値・非数値は 0 に丸める）。
  final int gems;

  /// 疲労回復量。現行の Player モデルには直接の疲労値が無いため
  /// **表示のみ**（付与は未接続）。値を偽って「回復した」と奏上しないための分離。
  final int fatigueRecovery;

  /// 謎の老人などが残すヒント文字列。
  final String? hint;

  const TownEventReward({
    this.xp = 0,
    this.gems = 0,
    this.fatigueRecovery = 0,
    this.hint,
  });

  static const TownEventReward empty = TownEventReward();

  /// 報酬マップを解釈する。null・未知キー・型不正でも例外を投げない。
  factory TownEventReward.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return empty;
    final rawHint = raw['hint'];
    final hint =
        rawHint is String && rawHint.trim().isNotEmpty ? rawHint.trim() : null;
    return TownEventReward(
      xp: _nonNegativeInt(raw['xp']),
      gems: _nonNegativeInt(raw['gems']),
      fatigueRecovery: _nonNegativeInt(raw['fatigue_recovery']),
      hint: hint,
    );
  }

  static int _nonNegativeInt(Object? value) {
    int parsed;
    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value.trim()) ?? 0;
    } else {
      parsed = 0;
    }
    return parsed < 0 ? 0 : parsed;
  }

  /// 付与対象の報酬が無いか。
  bool get isEmpty => xp == 0 && gems == 0 && hint == null;

  /// 実際に付与される報酬の表示ラベル（例: `EXP +50 / ジェム +3`）。
  /// 疲労回復は未接続のため含めない（付与していないものを付与したと書かない）。
  String get label {
    final parts = <String>[];
    if (xp > 0) parts.add('EXP +$xp');
    if (gems > 0) parts.add('ジェム +$gems');
    if (hint != null) parts.add('ヒント: $hint');
    return parts.join(' / ');
  }

  @override
  bool operator ==(Object other) =>
      other is TownEventReward &&
      other.xp == xp &&
      other.gems == gems &&
      other.fatigueRecovery == fatigueRecovery &&
      other.hint == hint;

  @override
  int get hashCode => Object.hash(xp, gems, fatigueRecovery, hint);

  @override
  String toString() =>
      'TownEventReward(xp: $xp, gems: $gems, fatigueRecovery: $fatigueRecovery, hint: $hint)';
}
