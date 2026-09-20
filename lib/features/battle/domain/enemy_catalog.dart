import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';

/// アセットパスから表示名を作る純粋関数。
///
/// 'assets/sprites/monsters/demons/demon_green_black_armor.png'
/// → 'Demon Green Black Armor'
///
/// ディレクトリ部と拡張子を除いたファイル名の '_' を空白に置換し、
/// 各語の語頭を大文字化する。空パスは空文字を返す。
String enemyDisplayNameFromAsset(String assetPath) {
  if (assetPath.isEmpty) return '';
  final fileName = assetPath.split('/').last;
  final stem = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  if (stem.isEmpty) return '';
  return stem
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

/// 敵討伐図鑑の1エントリ（1体ぶん）。
///
/// 状態・IOを持たない不変モデル。
class EnemyCatalogEntry {
  /// 敵アセットのパス（EnemyAssetService と共通の識別子）。
  final String assetPath;

  /// 敵のランク（S/A/B）。
  final QuestRank rank;

  /// 希少種なら true。
  final bool isRare;

  /// 希少種ラベル（例: "覚醒体"）。通常種は空文字。
  final String rarityLabel;

  /// 累計討伐回数。
  final int defeatCount;

  /// 初回討伐日時（未討伐なら null）。
  final DateTime? firstDefeatedAt;

  /// 最終討伐日時（未討討伐なら null）。
  final DateTime? lastDefeatedAt;

  /// 検証付きコンストラクタ（非const・本体で不変条件を強制する）。
  ///
  /// - [assetPath] が空なら [ArgumentError]。
  /// - [defeatCount] が負値なら 0 へ丸める。
  /// （assert は release で無効になるため本体で検証する）
  EnemyCatalogEntry({
    required String assetPath,
    required this.rank,
    this.isRare = false,
    this.rarityLabel = '',
    int defeatCount = 0,
    this.firstDefeatedAt,
    this.lastDefeatedAt,
  })  : assetPath = assetPath,
        defeatCount = defeatCount < 0 ? 0 : defeatCount {
    if (assetPath.isEmpty) {
      throw ArgumentError.value(assetPath, 'assetPath', 'must not be empty');
    }
  }

  /// 1度でも討伐していれば true。
  bool get isDiscovered => defeatCount > 0;

  /// アセットパスから生成した表示名。
  String get displayName => enemyDisplayNameFromAsset(assetPath);

  /// ランクラベル（'S' / 'A' / 'B'）。
  String get rankLabel => rank.name;

  /// 一部フィールドのみ差し替えた複製を作る。
  EnemyCatalogEntry copyWith({
    int? defeatCount,
    DateTime? firstDefeatedAt,
    DateTime? lastDefeatedAt,
  }) {
    return EnemyCatalogEntry(
      assetPath: assetPath,
      rank: rank,
      isRare: isRare,
      rarityLabel: rarityLabel,
      defeatCount: defeatCount ?? this.defeatCount,
      firstDefeatedAt: firstDefeatedAt ?? this.firstDefeatedAt,
      lastDefeatedAt: lastDefeatedAt ?? this.lastDefeatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EnemyCatalogEntry &&
      other.assetPath == assetPath &&
      other.rank == rank &&
      other.isRare == isRare &&
      other.rarityLabel == rarityLabel &&
      other.defeatCount == defeatCount &&
      other.firstDefeatedAt == firstDefeatedAt &&
      other.lastDefeatedAt == lastDefeatedAt;

  @override
  int get hashCode => Object.hash(
        assetPath,
        rank,
        isRare,
        rarityLabel,
        defeatCount,
        firstDefeatedAt,
        lastDefeatedAt,
      );

  @override
  String toString() =>
      'EnemyCatalogEntry($assetPath, rank=$rankLabel, defeats=$defeatCount)';
}

/// 敵討伐図鑑（全エントリの集合と達成率の集計）。
///
/// 状態・IOを持たない不変モデル。
class EnemyCatalog {
  /// 図鑑の全エントリ（不変）。
  final List<EnemyCatalogEntry> entries;

  /// コンストラクタ。渡したリストは複製して不変化する。
  EnemyCatalog(List<EnemyCatalogEntry> entries)
      : entries = List.unmodifiable(entries);

  /// 図鑑の総種数。
  int get totalCount => entries.length;

  /// 発見済み（討伐済み）の種数。
  int get discoveredCount => entries.where((e) => e.isDiscovered).length;

  /// 図鑑の達成率（0.0〜1.0）。total が 0 のときは 0.0（0除算回避）。
  double get completionRatio =>
      totalCount == 0 ? 0.0 : discoveredCount / totalCount;

  /// 図鑑の達成率（%）。
  int get completionPercent => (completionRatio * 100).round();

  /// 図鑑が完封（全種討伐）なら true。total が 0 のときは false。
  bool get isComplete => totalCount > 0 && discoveredCount == totalCount;

  /// 達成状況の表示用ラベル（例: '3 / 17 種'）。
  String get completionLabel => '$discoveredCount / $totalCount 種';

  /// 未発見のエントリ（entries 順）。
  List<EnemyCatalogEntry> get undiscovered =>
      entries.where((e) => !e.isDiscovered).toList();

  /// 希少種のエントリ（entries 順）。
  List<EnemyCatalogEntry> get rare =>
      entries.where((e) => e.isRare).toList();

  /// 累計討伐回数の合計。
  int get totalDefeats =>
      entries.fold<int>(0, (sum, e) => sum + e.defeatCount);

  /// 指定ランクのエントリ（entries 順）。
  List<EnemyCatalogEntry> entriesForRank(QuestRank rank) =>
      entries.where((e) => e.rank == rank).toList();

  @override
  bool operator ==(Object other) =>
      other is EnemyCatalog &&
      other.entries.length == entries.length &&
      other.entries.every((e) => entries.contains(e));

  @override
  int get hashCode => Object.hashAll(entries.map((e) => e.assetPath));

  @override
  String toString() => 'EnemyCatalog($completionLabel)';
}

/// 敵討伐図鑑の純粋サービス（IO・状態を持たない）。
class EnemyCatalogService {
  const EnemyCatalogService._();

  /// 図鑑の雛形（全17体）を作る。
  ///
  /// [EnemyAssetService.entriesForRank] を QuestRank.values の順（S,A,B）に
  /// 連結し、rank / isRare / rarityLabel を引き継ぐ。
  static List<EnemyCatalogEntry> allEntries() {
    final result = <EnemyCatalogEntry>[];
    for (final rank in QuestRank.values) {
      for (final asset in EnemyAssetService.entriesForRank(rank)) {
        result.add(
          EnemyCatalogEntry(
            assetPath: asset.assetPath,
            rank: rank,
            isRare: asset.isRare,
            rarityLabel: asset.rarityLabel,
          ),
        );
      }
    }
    return result;
  }

  /// エントリを図鑑表示順に並べ替える。
  ///
  /// S→A→B の順、同ランク内は isRare が先、その次に assetPath 昇順。
  /// 入力リストは破壊しない（非破壊）。
  static List<EnemyCatalogEntry> sortByRank(List<EnemyCatalogEntry> entries) {
    final rankOrder = {for (final r in QuestRank.values) r: r.index};
    final sorted = [...entries]..sort((a, b) {
        final rankCmp = rankOrder[a.rank]!.compareTo(rankOrder[b.rank]!);
        if (rankCmp != 0) return rankCmp;
        if (a.isRare != b.isRare) return a.isRare ? -1 : 1;
        return a.assetPath.compareTo(b.assetPath);
      });
    return sorted;
  }

  /// 未発見のエントリのみ抽出する。入力順を保持・非破壊。
  static List<EnemyCatalogEntry> filterUndiscovered(
    List<EnemyCatalogEntry> entries,
  ) {
    return entries.where((e) => !e.isDiscovered).toList();
  }

  /// 希少種のエントリのみ抽出する。入力順を保持・非破壊。
  static List<EnemyCatalogEntry> filterRare(List<EnemyCatalogEntry> entries) {
    return entries.where((e) => e.isRare).toList();
  }

  /// 戦績記録から図鑑を構築する。
  ///
  /// [template] ?? [allEntries] を雛形にし、[records] のうち
  /// **isVictory == true かつ enemyAssetPath が非null・非空** のものだけを
  /// 集計する。
  ///
  /// - defeatCount は 1 ずつ加算。
  /// - firstDefeatedAt は最古の occurredAt、lastDefeatedAt は最新の occurredAt。
  /// - 雛形に無い未知の assetPath は無視する。
  /// - [records] が空なら全滅（誰も討伐していない図鑑）。
  /// - 返り値の entries は sortByRank 済みで不変。
  static EnemyCatalog build({
    required List<BattleRecord> records,
    List<EnemyCatalogEntry>? template,
  }) {
    final baseEntries = (template ?? allEntries()).map((e) => e).toList();
    final byPath = {for (final e in baseEntries) e.assetPath: e};

    for (final record in records) {
      final path = record.enemyAssetPath;
      if (!record.isVictory || path == null || path.isEmpty) continue;
      final entry = byPath[path];
      if (entry == null) continue; // 未知の assetPath は無視
      final occurredAt = record.occurredAt;
      final first = entry.firstDefeatedAt == null ||
              occurredAt.isBefore(entry.firstDefeatedAt!)
          ? occurredAt
          : entry.firstDefeatedAt;
      final last = entry.lastDefeatedAt == null ||
              occurredAt.isAfter(entry.lastDefeatedAt!)
          ? occurredAt
          : entry.lastDefeatedAt;
      byPath[path] = entry.copyWith(
        defeatCount: entry.defeatCount + 1,
        firstDefeatedAt: first,
        lastDefeatedAt: last,
      );
    }

    return EnemyCatalog(sortByRank(byPath.values.toList()));
  }
}
