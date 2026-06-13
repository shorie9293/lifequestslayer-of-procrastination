import 'dart:math';

/// 町のレベルと経験値を管理するクラス。
///
/// プレイヤーの冒険者レベルとは別に、町自体が経験値を獲得して成長する。
/// クエスト完了時に町XPが加算され、閾値を超えると町レベルが上昇する。
class TownLevel {
  /// 町の現在レベル（1以上）
  int level;

  /// 現在のレベル内での累積経験値
  int xp;

  TownLevel({this.level = 1, this.xp = 0});

  /// 現在のレベルから次のレベルに必要な経験値を返す。
  int get xpToNext => _xpForLevel(level);

  /// 指定レベルに必要な経験値を計算する（Lv1→50, Lv10→~531）。
  static int _xpForLevel(int lvl) =>
      (50 * pow(1.3, lvl - 1)).round();

  /// 経験値を加算する。レベルアップした場合は true を返す。
  ///
  /// 複数レベル上昇した場合も true を返す。
  /// 溢れたXPは次のレベルに繰り越される。
  bool addXp(int amount) {
    if (amount <= 0) return false;

    xp += amount;
    bool leveledUp = false;

    while (xp >= xpToNext) {
      xp -= xpToNext;
      level++;
      leveledUp = true;
    }

    return leveledUp;
  }

  /// JSON互換のマップに変換する。
  Map<String, dynamic> toJson() => {
        'level': level,
        'xp': xp,
      };

  /// JSON互換のマップから復元する。
  factory TownLevel.fromJson(Map<String, dynamic> json) {
    return TownLevel(
      level: (json['level'] as int?) ?? 1,
      xp: (json['xp'] as int?) ?? 0,
    );
  }
}
