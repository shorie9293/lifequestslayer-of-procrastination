import 'job.dart';

/// A single node in a skill tree.
///
/// Nodes are statically defined — only [SkillTreeState] carries the
/// per-player progression that decides whether a node is visible or available.
class SkillNode {
  /// Unique identifier, e.g. `'war_flash'`.
  final String id;

  /// Which of the three class trees this node belongs to.
  final Job tree;

  /// Display name, e.g. `'一閃'`.
  final String name;

  /// Flavour description shown in the skill-picker UI.
  final String description;

  /// How many [Player.skillPoints] must be spent to unlock this node.
  final int pointCost;

  /// IDs of nodes that must already be unlocked before this node can be.
  final List<String> prerequisites;

  /// Visual row (0 = root).
  final int row;

  const SkillNode({
    required this.id,
    required this.tree,
    required this.name,
    required this.description,
    required this.pointCost,
    this.prerequisites = const [],
    this.row = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillNode &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// Static tree definition — 9 nodes across 3 paths
// ---------------------------------------------------------------------------

/// Every skill‑tree node in the game, keyed by its string ID.
///
/// This map is the single source of truth for node metadata.  Adding a
/// future node is as simple as appending a new entry here — no migrations
/// needed because [Player.unlockedSkillIds] is a `List<String>`.
const Map<String, SkillNode> skillTreeDefinition = {
  // ⚔️ Samurai  —  一閃 → 連撃 → 会心  (2 + 3 + 4)
  'war_flash': SkillNode(
    id: 'war_flash',
    tree: Job.samurai,
    name: '一閃',
    description: '攻撃時、まれに先制攻撃が発動。敵の行動前に追加ダメージを与える',
    pointCost: 2,
    row: 0,
  ),
  'war_combo': SkillNode(
    id: 'war_combo',
    tree: Job.samurai,
    name: '連撃',
    description: 'コンボ達成時、追加でEXPを獲得。連撃の回数に応じて報酬が増加する',
    pointCost: 3,
    prerequisites: ['war_flash'],
    row: 1,
  ),
  'war_critical': SkillNode(
    id: 'war_critical',
    tree: Job.samurai,
    name: '会心',
    description: '会心率が永続的に上昇。討伐時の獲得EXPにクリティカル倍率が乗る',
    pointCost: 4,
    prerequisites: ['war_combo'],
    row: 2,
  ),
  'war_zanshin': SkillNode(
    id: 'war_zanshin',
    tree: Job.samurai,
    name: '残心',
    description: '討伐後、残心の刻が発動。会心⚔️か戒め💧で振り返り、己を省みる',
    pointCost: 4,
    prerequisites: ['war_combo'],
    row: 2,
  ),

  // 🛡️ Monk  —  祈り → 治癒 → 加護  (2 + 3 + 4)
  'cle_prayer': SkillNode(
    id: 'cle_prayer',
    tree: Job.monk,
    name: '祈り',
    description: 'クエスト期限の延長が可能に。祈りを捧げて猶予を1日追加する',
    pointCost: 2,
    row: 0,
  ),
  'cle_heal': SkillNode(
    id: 'cle_heal',
    tree: Job.monk,
    name: '治癒',
    description: 'クエスト未完了によるペナルティを軽減。連続ログインの保護効果が上昇',
    pointCost: 3,
    prerequisites: ['cle_prayer'],
    row: 1,
  ),
  'cle_ward': SkillNode(
    id: 'cle_ward',
    tree: Job.monk,
    name: '加護',
    description: '週1回、ストリーク中断を防ぐ加護が発動。失敗しても連続記録が維持される',
    pointCost: 4,
    prerequisites: ['cle_heal'],
    row: 2,
  ),

  // 🔮 Mystic  —  先見 → 分割 → 転移  (2 + 3 + 4)
  'wiz_foresight': SkillNode(
    id: 'wiz_foresight',
    tree: Job.mystic,
    name: '先見',
    description: '未着手クエストの可視化。期限が近いクエストを優先表示する',
    pointCost: 2,
    row: 0,
  ),
  'wiz_split': SkillNode(
    id: 'wiz_split',
    tree: Job.mystic,
    name: '分割',
    description: '大クエストをサブクエストに分割可能に。分割数に応じて達成ボーナスが上昇',
    pointCost: 3,
    prerequisites: ['wiz_foresight'],
    row: 1,
  ),
  'wiz_transfer': SkillNode(
    id: 'wiz_transfer',
    tree: Job.mystic,
    name: '転移',
    description: '未完了クエストの期限を別の日に転移。計画の立て直しが容易になる',
    pointCost: 4,
    prerequisites: ['wiz_split'],
    row: 2,
  ),
};

// ---------------------------------------------------------------------------
// Skill‑point economy
// ---------------------------------------------------------------------------

/// Returns the **total** skill points the player has ever earned based on
/// their current Adventurer level.
///
/// Formula: `max(0, (adventurerLevel - 2) ~/ 3)`
///
/// | Adventurer Lv | 1-2 | 3-5 | 6-8 | 9-11 | … | 96-98 | 99 |
/// |---------------|-----|-----|-----|------|---|-------|----|
/// | Points earned | 0   | 1   | 2   | 3    | … | 32    | 33 |
int totalEarnedSkillPoints(int adventurerLevel) {
  return adventurerLevel ~/ 3;
}

/// Sum of [SkillNode.pointCost] for every node whose ID appears in
/// [unlockedIds].
int totalSpentSkillPoints(Iterable<String> unlockedIds) {
  int spent = 0;
  for (final id in unlockedIds) {
    final node = skillTreeDefinition[id];
    if (node != null) spent += node.pointCost;
  }
  return spent;
}

/// Unspent skill points the player should currently have, derived from
/// Adventurer level minus the cost of already-unlocked nodes.
int availableSkillPoints(int adventurerLevel, Iterable<String> unlockedIds) {
  return totalEarnedSkillPoints(adventurerLevel) -
      totalSpentSkillPoints(unlockedIds);
}

// ---------------------------------------------------------------------------
// Progression helpers (computed, never persisted)
// ---------------------------------------------------------------------------

/// Whether [node] can be unlocked *right now* given the player's state.
bool canUnlockNode(
  SkillNode node, {
  required Iterable<String> unlockedIds,
  required int skillPoints,
}) {
  // Already unlocked?
  if (unlockedIds.contains(node.id)) return false;
  // Affordable?
  if (skillPoints < node.pointCost) return false;
  // Prerequisites met?
  for (final prereq in node.prerequisites) {
    if (!unlockedIds.contains(prereq)) return false;
  }
  return true;
}

/// Whether [node] should be visible in the tree UI.
///
/// A node is visible when either:
/// - it has no prerequisites (root node), OR
/// - at least one of its prerequisites is already unlocked.
bool isNodeVisible(
  SkillNode node, {
  required Iterable<String> unlockedIds,
}) {
  if (node.prerequisites.isEmpty) return true;
  return node.prerequisites.any((id) => unlockedIds.contains(id));
}

/// All nodes that are visible given the current set of unlocked IDs.
Iterable<SkillNode> visibleNodes(Iterable<String> unlockedIds) {
  return skillTreeDefinition.values.where(
    (n) => isNodeVisible(n, unlockedIds: unlockedIds),
  );
}

/// All nodes that are currently unlockable.
Iterable<SkillNode> unlockableNodes({
  required Iterable<String> unlockedIds,
  required int skillPoints,
}) {
  return skillTreeDefinition.values.where(
    (n) => canUnlockNode(n, unlockedIds: unlockedIds, skillPoints: skillPoints),
  );
}
