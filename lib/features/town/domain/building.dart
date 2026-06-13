/// 町に建設可能な建物の種類。
enum Building {
  /// 宿屋 — 疲労回復を促進する
  inn,

  /// 商店 — ショップアイテムの割引
  shop,

  /// 鍛冶屋 — 装備・ギアをアンロック
  blacksmith,

  /// 見張り台 — クエスト難易度を事前開示
  watchtower;

  /// 建物の表示名（日本語）。
  String get displayName {
    switch (this) {
      case Building.inn:
        return '宿屋';
      case Building.shop:
        return '商店';
      case Building.blacksmith:
        return '鍛冶屋';
      case Building.watchtower:
        return '見張り台';
    }
  }

  /// この建物がアンロックされる町レベル。
  int get unlockTownLevel {
    switch (this) {
      case Building.inn:
        return 1;
      case Building.shop:
        return 3;
      case Building.blacksmith:
        return 7;
      case Building.watchtower:
        return 12;
    }
  }

  /// 建物名の文字列から Building を取得する。
  static Building fromString(String name) {
    return Building.values.firstWhere(
      (b) => b.name == name,
      orElse: () => throw ArgumentError('Unknown building: $name'),
    );
  }
}

/// 個別の建物の状態（レベルとアンロック状態）を管理するクラス。
class BuildingState {
  /// 建物の最大レベル。
  static const int maxLevel = 5;

  /// 建物の種類。
  final Building building;

  /// 現在の建物レベル（1〜5）。
  int level;

  BuildingState({
    required this.building,
    this.level = 1,
  });

  /// 指定された町レベルでこの建物がアンロックされているか。
  bool isUnlocked(int townLevel) {
    return townLevel >= building.unlockTownLevel;
  }

  /// 次のレベルへのアップグレードに必要なコイン数。
  int get upgradeCoinCost => level * 100;

  /// アップグレード可能か（最大レベル未満）。
  bool get canUpgrade => level < maxLevel;

  /// レベルを1つ上げる。成功したら true、最大レベルなら false。
  bool upgrade() {
    if (!canUpgrade) return false;
    level++;
    return true;
  }

  /// 現在のレベルに応じた建物効果の説明を返す。
  String getEffect() {
    switch (building) {
      case Building.inn:
        return '疲労回復時間 ${level * 10}% 短縮';
      case Building.shop:
        return 'ショップ割引 ${level * 5}%';
      case Building.blacksmith:
        return '装備強化 +${level}';
      case Building.watchtower:
        return 'クエスト難易度 Lv.${level} まで表示';
    }
  }

  /// JSON互換のマップに変換する。
  Map<String, dynamic> toJson() => {
        'building': building.name,
        'level': level,
      };

  /// JSON互換のマップから復元する。
  factory BuildingState.fromJson(Map<String, dynamic> json) {
    return BuildingState(
      building: Building.fromString(json['building'] as String),
      level: (json['level'] as int?) ?? 1,
    );
  }
}
