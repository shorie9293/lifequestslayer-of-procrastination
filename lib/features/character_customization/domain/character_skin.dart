/// キャラクタースキンの装備スロット。
enum SkinSlot {
  /// 顔パーツ
  face,

  /// 髪型
  hair,

  /// 鎧（胴装備）
  armor,

  /// 武器
  weapon,

  /// 盾
  shield;

  /// スロットの表示名（日本語）。
  String get displayName {
    switch (this) {
      case SkinSlot.face:
        return '顔';
      case SkinSlot.hair:
        return '髪型';
      case SkinSlot.armor:
        return '鎧';
      case SkinSlot.weapon:
        return '武器';
      case SkinSlot.shield:
        return '盾';
    }
  }
}

/// 5部位のキャラクタースキン設定。
///
/// 各スロットに装備中のスキンIDを保持する。
/// 未装備時は "default"。
class CharacterSkin {
  final String faceId;
  final String hairId;
  final String armorId;
  final String weaponId;
  final String shieldId;

  const CharacterSkin({
    this.faceId = 'default',
    this.hairId = 'default',
    this.armorId = 'default',
    this.weaponId = 'default',
    this.shieldId = 'default',
  });

  /// 指定スロットの現在値を返す。
  String getSlot(SkinSlot slot) {
    switch (slot) {
      case SkinSlot.face:
        return faceId;
      case SkinSlot.hair:
        return hairId;
      case SkinSlot.armor:
        return armorId;
      case SkinSlot.weapon:
        return weaponId;
      case SkinSlot.shield:
        return shieldId;
    }
  }

  /// 指定スロットだけ変更した新しい [CharacterSkin] を返す。
  CharacterSkin withSlot(SkinSlot slot, String skinId) {
    switch (slot) {
      case SkinSlot.face:
        return copyWith(faceId: skinId);
      case SkinSlot.hair:
        return copyWith(hairId: skinId);
      case SkinSlot.armor:
        return copyWith(armorId: skinId);
      case SkinSlot.weapon:
        return copyWith(weaponId: skinId);
      case SkinSlot.shield:
        return copyWith(shieldId: skinId);
    }
  }

  /// 一部のスロットだけ変更したコピーを返す。
  CharacterSkin copyWith({
    String? faceId,
    String? hairId,
    String? armorId,
    String? weaponId,
    String? shieldId,
  }) {
    return CharacterSkin(
      faceId: faceId ?? this.faceId,
      hairId: hairId ?? this.hairId,
      armorId: armorId ?? this.armorId,
      weaponId: weaponId ?? this.weaponId,
      shieldId: shieldId ?? this.shieldId,
    );
  }

  /// Mapに変換（永続化用）。
  Map<String, dynamic> toMap() => {
        'faceId': faceId,
        'hairId': hairId,
        'armorId': armorId,
        'weaponId': weaponId,
        'shieldId': shieldId,
      };

  /// Mapから復元。
  factory CharacterSkin.fromMap(Map<String, dynamic> map) {
    return CharacterSkin(
      faceId: map['faceId'] as String? ?? 'default',
      hairId: map['hairId'] as String? ?? 'default',
      armorId: map['armorId'] as String? ?? 'default',
      weaponId: map['weaponId'] as String? ?? 'default',
      shieldId: map['shieldId'] as String? ?? 'default',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterSkin &&
          faceId == other.faceId &&
          hairId == other.hairId &&
          armorId == other.armorId &&
          weaponId == other.weaponId &&
          shieldId == other.shieldId;

  @override
  int get hashCode => Object.hash(faceId, hairId, armorId, weaponId, shieldId);

  @override
  String toString() =>
      'CharacterSkin(face: $faceId, hair: $hairId, armor: $armorId, weapon: $weaponId, shield: $shieldId)';
}

/// スキン1つ分の定義。
///
/// [id] で一意に識別され、[slot] で装備部位を指定する。
/// 解放条件は複数指定可能で、すべて満たす（AND）必要がある。
class SkinDefinition {
  final String id;
  final SkinSlot slot;
  final String name;
  final String icon;
  final String description;
  final String unlockConditionDescription;

  /// 解放に必要な称号（nullなら条件なし）。
  final String? requiredTitle;

  /// 解放に必要な冒険者レベル（nullなら条件なし）。
  final int? requiredLevel;

  /// 解放に必要なストリーク日数（nullなら条件なし）。
  final int? requiredStreakDays;

  /// 解放に必要な累計討伐数（nullなら条件なし）。
  final int? requiredTotalTasks;

  const SkinDefinition({
    required this.id,
    required this.slot,
    required this.name,
    required this.icon,
    this.description = '',
    this.unlockConditionDescription = '',
    this.requiredTitle,
    this.requiredLevel,
    this.requiredStreakDays,
    this.requiredTotalTasks,
  });

  /// 指定されたプレイヤー状態でこのスキンが解放されているかを返す。
  ///
  /// すべての指定条件を満たす（AND）場合に true。
  /// デフォルトスキン（id='default'）は常に解放済み。
  bool isUnlocked({
    int level = 1,
    int streakDays = 0,
    int totalTasks = 0,
    List<String> titles = const [],
  }) {
    if (id == 'default') return true;
    final reqTitle = requiredTitle;
    final reqLevel = requiredLevel;
    final reqStreak = requiredStreakDays;
    final reqTasks = requiredTotalTasks;
    if (reqTitle != null && !titles.contains(reqTitle)) return false;
    if (reqLevel != null && level < reqLevel) return false;
    if (reqStreak != null && streakDays < reqStreak) return false;
    if (reqTasks != null && totalTasks < reqTasks) return false;
    return true;
  }
}

/// 全スキンのカタログ（レジストリ）。
///
/// スキンはここで一元管理され、スロット別・解放条件別に取得できる。
class SkinCatalog {
  SkinCatalog._();

  /// 全スキン定義。
  static const List<SkinDefinition> allSkins = [
    // ── デフォルト（全スロット共通） ──
    SkinDefinition(
      id: 'default',
      slot: SkinSlot.face,
      name: 'デフォルト',
      icon: '😶',
      description: '初期装備',
    ),
    SkinDefinition(
      id: 'default',
      slot: SkinSlot.hair,
      name: 'デフォルト',
      icon: '💇',
      description: '初期装備',
    ),
    SkinDefinition(
      id: 'default',
      slot: SkinSlot.armor,
      name: 'デフォルト',
      icon: '👘',
      description: '初期装備',
    ),
    SkinDefinition(
      id: 'default',
      slot: SkinSlot.weapon,
      name: 'デフォルト',
      icon: '👊',
      description: '初期装備',
    ),
    SkinDefinition(
      id: 'default',
      slot: SkinSlot.shield,
      name: 'デフォルト',
      icon: '🤚',
      description: '初期装備',
    ),

    // ── 顔パーツ ──
    SkinDefinition(
      id: 'warrior_face',
      slot: SkinSlot.face,
      name: '戦士の面構え',
      icon: '😤',
      description: '幾多の戦いを経た精悍な顔つき',
      unlockConditionDescription: '称号「歴戦の勇士」を獲得',
      requiredTitle: '歴戦の勇士',
    ),
    SkinDefinition(
      id: 'sage_face',
      slot: SkinSlot.face,
      name: '賢者の面持ち',
      icon: '🧘',
      description: '深い知恵を湛えた穏やかな表情',
      unlockConditionDescription: '称号「知識の探究者」を獲得',
      requiredTitle: '知識の探究者',
    ),
    SkinDefinition(
      id: 'dragon_helm',
      slot: SkinSlot.face,
      name: '竜の兜',
      icon: '🐲',
      description: '伝説の竜を討ち取った証',
      unlockConditionDescription: '称号「伝説の討伐者」を獲得',
      requiredTitle: '伝説の討伐者',
    ),

    // ── 髪型 ──
    SkinDefinition(
      id: 'spiky',
      slot: SkinSlot.hair,
      name: '逆立て髪',
      icon: '⚡',
      description: '気合いの入った鋭い髪型',
      unlockConditionDescription: '冒険者Lv.5達成',
      requiredLevel: 5,
    ),
    SkinDefinition(
      id: 'ponytail',
      slot: SkinSlot.hair,
      name: '結い髪',
      icon: '🎀',
      description: '後ろで束ねた実戦的な髪型',
      unlockConditionDescription: 'ストリーク7日達成',
      requiredStreakDays: 7,
    ),
    SkinDefinition(
      id: 'flame_crown',
      slot: SkinSlot.hair,
      name: '炎の冠',
      icon: '👑',
      description: '絶え間なき情熱の証',
      unlockConditionDescription: 'ストリーク30日達成',
      requiredStreakDays: 30,
    ),

    // ── 鎧 ──
    SkinDefinition(
      id: 'leather_armor',
      slot: SkinSlot.armor,
      name: '革の鎧',
      icon: '🧥',
      description: '軽量で動きやすい革鎧',
      unlockConditionDescription: '累計10クエスト討伐',
      requiredTotalTasks: 10,
    ),
    SkinDefinition(
      id: 'iron_armor',
      slot: SkinSlot.armor,
      name: '鉄の鎧',
      icon: '🛡️',
      description: '堅固な鉄の鎧',
      unlockConditionDescription: '称号「鉄壁の守り手」を獲得',
      requiredTitle: '鉄壁の守り手',
    ),
    SkinDefinition(
      id: 'royal_armor',
      slot: SkinSlot.armor,
      name: '王家の鎧',
      icon: '👑',
      description: '王族のみが纏うことを許される黄金の鎧',
      unlockConditionDescription: '冒険者Lv.50達成',
      requiredLevel: 50,
    ),

    // ── 武器 ──
    SkinDefinition(
      id: 'bronze_sword',
      slot: SkinSlot.weapon,
      name: '青銅の剣',
      icon: '🗡️',
      description: '旅立ちにふさわしい最初の一振り',
      unlockConditionDescription: '累計5クエスト討伐',
      requiredTotalTasks: 5,
    ),
    SkinDefinition(
      id: 'longsword',
      slot: SkinSlot.weapon,
      name: '長剣',
      icon: '⚔️',
      description: '歴戦の証たる長剣',
      unlockConditionDescription: '累計50クエスト討伐',
      requiredTotalTasks: 50,
    ),
    SkinDefinition(
      id: 'master_sword',
      slot: SkinSlot.weapon,
      name: '免許皆伝の剣',
      icon: '⚔️',
      description: '修行を極めし者のみが振るえる剣',
      unlockConditionDescription: 'Lv.30以上かつストリーク7日以上',
      requiredLevel: 30,
      requiredStreakDays: 7,
    ),
    SkinDefinition(
      id: 'dragon_slayer',
      slot: SkinSlot.weapon,
      name: '竜殺しの大剣',
      icon: '🐉',
      description: '竜を屠るために鍛えられた伝説の武器',
      unlockConditionDescription: '称号「伝説の討伐者」を獲得',
      requiredTitle: '伝説の討伐者',
    ),

    // ── 盾 ──
    SkinDefinition(
      id: 'wooden_shield',
      slot: SkinSlot.shield,
      name: '木の盾',
      icon: '🪵',
      description: '旅の始まりを守る小さな盾',
      unlockConditionDescription: '累計3クエスト討伐',
      requiredTotalTasks: 3,
    ),
    SkinDefinition(
      id: 'round_shield',
      slot: SkinSlot.shield,
      name: '円盾',
      icon: '🔵',
      description: 'バランスの良い標準的な盾',
      unlockConditionDescription: '累計30クエスト討伐',
      requiredTotalTasks: 30,
    ),
    SkinDefinition(
      id: 'veteran_shield',
      slot: SkinSlot.shield,
      name: '歴戦の盾',
      icon: '🛡️',
      description: '幾多の傷が物語る信頼の盾',
      unlockConditionDescription: '累計100クエスト討伐',
      requiredTotalTasks: 100,
    ),
    SkinDefinition(
      id: 'aegis',
      slot: SkinSlot.shield,
      name: '神盾アイギス',
      icon: '✨',
      description: '神々の加護を宿す聖なる盾',
      unlockConditionDescription: '称号「鉄壁の守り手」かつLv.50以上',
      requiredTitle: '鉄壁の守り手',
      requiredLevel: 50,
    ),
  ];

  /// 指定スロットの全スキン定義を返す。
  static List<SkinDefinition> skinsForSlot(SkinSlot slot) {
    return allSkins.where((s) => s.slot == slot).toList();
  }

  /// IDでスキン定義を検索する。見つからない場合はnull。
  /// 複数マッチ時（デフォルトスキンなど）は最初のマッチを返す。
  static SkinDefinition? findById(String id) {
    for (final skin in allSkins) {
      if (skin.id == id) return skin;
    }
    return null;
  }

  /// プレイヤー状態で解放済みの全スキンを返す。
  static List<SkinDefinition> unlockedSkins({
    int level = 1,
    int streakDays = 0,
    int totalTasks = 0,
    List<String> titles = const [],
  }) {
    return allSkins
        .where((s) => s.isUnlocked(
              level: level,
              streakDays: streakDays,
              totalTasks: totalTasks,
              titles: titles,
            ))
        .toList();
  }

  /// 指定スロットで解放済みのスキン一覧を返す。
  static List<SkinDefinition> unlockedSkinsForSlot(
    SkinSlot slot, {
    int level = 1,
    int streakDays = 0,
    int totalTasks = 0,
    List<String> titles = const [],
  }) {
    return unlockedSkins(
      level: level,
      streakDays: streakDays,
      totalTasks: totalTasks,
      titles: titles,
    ).where((s) => s.slot == slot).toList();
  }
}
