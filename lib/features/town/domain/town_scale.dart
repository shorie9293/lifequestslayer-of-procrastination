/// 町の発展段階を表す列挙型。
///
/// プレイヤーの冒険者レベルに応じて町の姿が変化する。
/// [fromLevel] で現在のレベルから段階を取得できる。
enum TownScale {
  /// Lv.1〜10: 荒野のキャンプ
  wildernessCamp,

  /// Lv.11〜25: 小さな集落
  smallSettlement,

  /// Lv.26〜50: 活気ある町
  livelyTown,

  /// Lv.51〜100: 王都
  royalCapital,

  /// Lv.101+: 天空の都
  skyCity;

  /// プレイヤーレベルから現在の町の発展段階を返す。
  ///
  /// レベルが0以下の場合は [wildernessCamp] を返す（下限防衛）。
  static TownScale fromLevel(int level) {
    if (level >= 101) return skyCity;
    if (level >= 51) return royalCapital;
    if (level >= 26) return livelyTown;
    if (level >= 11) return smallSettlement;
    return wildernessCamp;
  }

  /// 町の発展段階の表示名（日本語）。
  String get displayName {
    switch (this) {
      case TownScale.wildernessCamp:
        return '荒野のキャンプ';
      case TownScale.smallSettlement:
        return '小さな集落';
      case TownScale.livelyTown:
        return '活気ある町';
      case TownScale.royalCapital:
        return '王都';
      case TownScale.skyCity:
        return '天空の都';
    }
  }

  /// 次の発展段階。最大段階（[skyCity]）の場合は null。
  TownScale? get nextScale {
    switch (this) {
      case TownScale.wildernessCamp:
        return TownScale.smallSettlement;
      case TownScale.smallSettlement:
        return TownScale.livelyTown;
      case TownScale.livelyTown:
        return TownScale.royalCapital;
      case TownScale.royalCapital:
        return TownScale.skyCity;
      case TownScale.skyCity:
        return null;
    }
  }

  /// 次の段階に進むために必要な冒険者レベル。
  /// 最大段階（[skyCity]）の場合は null。
  int? get nextLevelForUpgrade {
    switch (this) {
      case TownScale.wildernessCamp:
        return 11;
      case TownScale.smallSettlement:
        return 26;
      case TownScale.livelyTown:
        return 51;
      case TownScale.royalCapital:
        return 101;
      case TownScale.skyCity:
        return null;
    }
  }
}
