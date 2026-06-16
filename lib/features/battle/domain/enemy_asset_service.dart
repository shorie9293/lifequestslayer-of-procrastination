import 'dart:math';
import 'package:rpg_todo/domain/models/task.dart';

/// 敵アセットのエントリ。
///
/// [assetPath] は Flutter のアセットパス、
/// [isRare] は希少種フラグ、
/// [rarityLabel] は希少種のラベル（例: "覚醒体"）、
/// [xpMultiplier] は討伐時の経験値倍率。
class EnemyAssetEntry {
  final String assetPath;
  final bool isRare;
  final String rarityLabel;
  final double xpMultiplier;
  /// 重み付き抽選の重み（大きいほど選ばれやすい）
  final int weight;

  const EnemyAssetEntry({
    required this.assetPath,
    this.isRare = false,
    this.rarityLabel = '',
    this.xpMultiplier = 1.0,
    this.weight = 4,
  });
}

/// 敵グラフィックのアセット割当サービス。
///
/// クエスト作成時にランク（S/A/B）に応じたランダムなピクセルアート
/// スプライトを**重み付き抽選**で返す。
///
/// 各ランクに1〜2体の「希少種」(rare) が存在し、通常種より出現率が低いが
/// 討伐時に +50% の経験値ボーナスが付与される。
///
/// 資産庫: `assets/sprites/monsters/` 配下の17体。
///
/// ランク別内訳:
/// - Sランク: ボス級 6体（うち希少種2体: 黒翼の赤鬼, 多腕の緑鬼）
/// - Aランク: 精鋭級 8体（うち希少種2体: 赤鬼武者, 緑杖の赤鬼）
/// - Bランク: 雑魚級 3体（うち希少種1体: 骸骨武者）
class EnemyAssetService {
  EnemyAssetService._();

  static final _random = Random();

  /// 希少種の経験値倍率。
  static const double _rareXpMultiplier = 1.5;

  // ── Sランク（ボス級） ──

  static const _sRankEntries = [
    // 通常種 (weight=4)
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_green_black_armor.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_red_black_armor.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_red_winged.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/golem_grey_armored.png',
    ),
    // 希少種 (weight=1, xp×1.5)
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_red_black_winged.png',
      isRare: true,
      rarityLabel: '覚醒体',
      xpMultiplier: _rareXpMultiplier,
      weight: 1,
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_green_multi_arm.png',
      isRare: true,
      rarityLabel: '変異種',
      xpMultiplier: _rareXpMultiplier,
      weight: 1,
    ),
  ];

  // ── Aランク（精鋭級） ──

  static const _aRankEntries = [
    // 通常種 (weight=4)
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_green_shield.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_orange_armored.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/oni/ogre_green.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/oni/oni_red_horned.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/yokai/demon_head_red_floating.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/yokai/spirit_white_red_floating.png',
    ),
    // 希少種 (weight=1, xp×1.5)
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/oni/oni_red_samurai.png',
      isRare: true,
      rarityLabel: '歴戦の個体',
      xpMultiplier: _rareXpMultiplier,
      weight: 1,
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_red_green_staff.png',
      isRare: true,
      rarityLabel: '呪術種',
      xpMultiplier: _rareXpMultiplier,
      weight: 1,
    ),
  ];

  // ── Bランク（雑魚級） ──

  static const _bRankEntries = [
    // 通常種 (weight=4)
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/beasts/beast_grey_armored.png',
    ),
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/beasts/owl_creature_small.png',
    ),
    // 希少種 (weight=1, xp×1.5)
    EnemyAssetEntry(
      assetPath: 'assets/sprites/monsters/undead/skeletal_samurai_dark.png',
      isRare: true,
      rarityLabel: '亡霊武者',
      xpMultiplier: _rareXpMultiplier,
      weight: 1,
    ),
  ];

  /// 指定ランクのエントリリストを取得。
  static List<EnemyAssetEntry> _entriesForRank(QuestRank rank) {
    return switch (rank) {
      QuestRank.S => _sRankEntries,
      QuestRank.A => _aRankEntries,
      QuestRank.B => _bRankEntries,
    };
  }

  /// 重み付きランダム選定で敵アセットエントリを返す。
  ///
  /// 希少種は通常種の 1/4 の確率で出現する。
  static EnemyAssetEntry randomEntryForRank(QuestRank rank) {
    final entries = _entriesForRank(rank);
    final totalWeight = entries.fold<int>(0, (sum, e) => sum + e.weight);
    var roll = _random.nextInt(totalWeight);
    for (final entry in entries) {
      roll -= entry.weight;
      if (roll < 0) return entry;
    }
    return entries.last; // fallback
  }

  /// 指定ランクのアセットパスをランダムに選ぶ（後方互換）。
  static String randomAssetForRank(QuestRank rank) {
    return randomEntryForRank(rank).assetPath;
  }

  /// 指定ランクの経験値倍率をランダム選定して返す。
  /// [assetPath] が指定された場合はそのエントリの倍率を返す。
  static double xpMultiplierForRank(QuestRank rank) {
    return randomEntryForRank(rank).xpMultiplier;
  }

  /// [assetPath] から対応するエントリを検索し XP 倍率を返す。
  /// 見つからない場合は 1.0 を返す。
  static double xpMultiplierForAsset(String? assetPath) {
    if (assetPath == null) return 1.0;
    for (final rank in QuestRank.values) {
      for (final entry in _entriesForRank(rank)) {
        if (entry.assetPath == assetPath) return entry.xpMultiplier;
      }
    }
    return 1.0;
  }

  /// [assetPath] が希少種かどうかを返す。
  static bool isRareAsset(String? assetPath) {
    if (assetPath == null) return false;
    for (final rank in QuestRank.values) {
      for (final entry in _entriesForRank(rank)) {
        if (entry.assetPath == assetPath) return entry.isRare;
      }
    }
    return false;
  }

  /// [assetPath] の希少種ラベルを返す。通常種は空文字列。
  static String rarityLabelForAsset(String? assetPath) {
    if (assetPath == null) return '';
    for (final rank in QuestRank.values) {
      for (final entry in _entriesForRank(rank)) {
        if (entry.assetPath == assetPath) return entry.rarityLabel;
      }
    }
    return '';
  }

  /// ランク別の全エントリを取得（デバッグ・テスト用）。
  static List<EnemyAssetEntry> entriesForRank(QuestRank rank) {
    return List.unmodifiable(_entriesForRank(rank));
  }

  /// ランク別のアセットパス一覧を取得（後方互換）。
  static List<String> assetsForRank(QuestRank rank) {
    return _entriesForRank(rank).map((e) => e.assetPath).toList();
  }

  /// ランク別のアセット数を返す。
  static int assetCount(QuestRank rank) {
    return _entriesForRank(rank).length;
  }
}
