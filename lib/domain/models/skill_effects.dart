import 'job.dart';

/// Concrete numerical effect configuration for a skill tree node.
///
/// Each [SkillEffectConfig] maps one [SkillNode.id] to its balanced stats.
/// Use [SkillEffectService] to resolve and apply these effects in task
/// completion flows.
///
/// ## Design principles (RICE 96 — high impact, reach, confidence)
///
/// | Path     | Theme              | Key Stats                         |
/// |----------|--------------------|-----------------------------------|
/// | Samurai  | Speed / Crit       | combo, crit, pre-emptive bonus    |
/// | Monk     | Healing / Buffs    | penalty reduction, streak protect |
/// | Mystic   | Efficiency / Plan  | late-bonus window, subquest, early|
///
/// ## Progression calibration
///
/// At Lv 27 (9 skill points), a player can unlock ONE full path.
/// At Lv 54 (18 pts), unlock TWO full paths.
/// At Lv 81 (27 pts), unlock ALL THREE paths.
///
/// Each path's total EXP gain potential is roughly equivalent (~25-35%
/// average increase at full unlock), but through different mechanics:
/// - Samurai: bursty (crit + combo spikes)
/// - Monk: protective (minimizes losses, steady bonus)
/// - Mystic: strategic (rewards planning and subquest use)
class SkillEffectConfig {
  /// The skill node ID this effect belongs to.
  final String nodeId;

  /// Which job tree this node is in.
  final Job tree;

  // ━━━ EXP modifiers ━━━

  /// Always-on EXP multiplier (1.0 = no change).
  final double baseExpMultiplier;

  /// Chance (0.0–1.0) for a one-time bonus EXP multiplier to trigger.
  final double bonusExpChance;
  /// Bonus EXP multiplier when [bonusExpChance] triggers (additive, e.g. 0.40 = +40%).
  final double bonusExpMultiplier;

  /// Chance (0.0–1.0) for a critical hit.
  final double critChance;
  /// Critical hit EXP multiplier (e.g. 2.0 = 2× EXP).
  final double critMultiplier;

  // ━━━ Combo modifiers ━━━

  /// Bonus EXP awarded per combo count (adds to the base +10/combo).
  final int comboExpPerCount;
  /// Added to the base combo multiplier step (default 0.1).
  final double comboStepBonus;

  // ━━━ Penalty / Protection modifiers ━━━

  /// Fraction (0.0–1.0) by which overdue penalty is reduced.
  /// E.g. 0.50 → 50% penalty becomes 25%.
  final double penaltyReduction;

  /// Bonus multiplier applied to tasks with streak ≥ [streakBonusMinStreak].
  final double streakBonusMultiplier;
  /// Minimum streak days required to trigger [streakBonusMultiplier].
  final int streakBonusMinStreak;

  // ━━━ Window / Planning modifiers ━━━

  /// Extended near-deadline bonus window in hours (base is 1h).
  final int lateBonusWindowHours;

  /// Bonus multiplier for completing ALL sub-quests of a task.
  final double subquestCompletionBonus;
  /// Bonus multiplier per individual sub-quest completion.
  final double perSubquestBonus;

  /// Bonus multiplier for completing tasks more than [earlyBonusThresholdHours] before deadline.
  final double earlyBonusMultiplier;
  /// Hours before deadline to qualify for the early bonus.
  final int earlyBonusThresholdHours;

  const SkillEffectConfig({
    required this.nodeId,
    required this.tree,
    this.baseExpMultiplier = 1.0,
    this.bonusExpChance = 0.0,
    this.bonusExpMultiplier = 0.0,
    this.critChance = 0.0,
    this.critMultiplier = 1.0,
    this.comboExpPerCount = 10,
    this.comboStepBonus = 0.0,
    this.penaltyReduction = 0.0,
    this.streakBonusMultiplier = 0.0,
    this.streakBonusMinStreak = 0,
    this.lateBonusWindowHours = 1,
    this.subquestCompletionBonus = 0.0,
    this.perSubquestBonus = 0.0,
    this.earlyBonusMultiplier = 0.0,
    this.earlyBonusThresholdHours = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillEffectConfig &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;

  @override
  String toString() => 'SkillEffectConfig($nodeId)';
}

// ═══════════════════════════════════════════════════════════════════════════
// Balanced effect definitions — 9 nodes across 3 paths
// ═══════════════════════════════════════════════════════════════════════════

/// Every skill node's concrete effect configuration, keyed by its string ID.
///
/// This map is the single source of truth for numerical balancing.
/// The [SkillEffectService] reads from here to apply effects at runtime.
const Map<String, SkillEffectConfig> skillEffectConfig = {
  // ═══ Samurai Path — Speed / Crit ═══
  //
  // Theme: Burst damage. Combo spikes + crit lottery give the Samurai
  // the highest potential single-task EXP, but with variance.
  // Full path (9 pts): ~30% average EXP increase.

  // 一閃 (Flash) — 15% chance for +40% bonus EXP. Pre-emptive strike.
  'war_flash': SkillEffectConfig(
    nodeId: 'war_flash',
    tree: Job.samurai,
    bonusExpChance: 0.15,
    bonusExpMultiplier: 0.40,
  ),

  // 連撃 (Combo) — Enhanced combo: +20 EXP/combo (up from 10),
  // combo multiplier step +0.05 (from 0.1 → 0.15).
  'war_combo': SkillEffectConfig(
    nodeId: 'war_combo',
    tree: Job.samurai,
    comboExpPerCount: 20,       // base is 10, so effective +10 per combo
    comboStepBonus: 0.05,       // base is 0.10, so effective 0.15
  ),

  // 会心 (Critical) — 10% chance for 2× EXP on any task completion.
  'war_critical': SkillEffectConfig(
    nodeId: 'war_critical',
    tree: Job.samurai,
    critChance: 0.10,
    critMultiplier: 2.0,
  ),

  // 残心 (Zanshin) — Post-battle reflection toggle. No EXP effect; behavioural only.
  'war_zanshin': SkillEffectConfig(
    nodeId: 'war_zanshin',
    tree: Job.samurai,
    baseExpMultiplier: 1.0,
  ),

  // ═══ Monk Path — Healing / Buffs ═══
  //
  // Theme: Damage mitigation. Reduces losses rather than adding gains,
  // making Monk the safest path for streak-conscious players.
  // Full path (9 pts): prevents ~30% potential EXP loss.

  // 祈り (Prayer) — +5% base EXP. Nurtures engagement.
  'cle_prayer': SkillEffectConfig(
    nodeId: 'cle_prayer',
    tree: Job.monk,
    baseExpMultiplier: 1.05,
  ),

  // 治癒 (Heal) — Reduces overdue penalty by 50%.
  // Overdue tasks normally lose 50% EXP; with Heal they lose only 25%.
  'cle_heal': SkillEffectConfig(
    nodeId: 'cle_heal',
    tree: Job.monk,
    penaltyReduction: 0.50,
  ),

  // 加護 (Ward) — +10% EXP for tasks with streak ≥ 3 days.
  // Also enables once-per-week streak break protection (behavioural).
  'cle_ward': SkillEffectConfig(
    nodeId: 'cle_ward',
    tree: Job.monk,
    streakBonusMultiplier: 0.10,
    streakBonusMinStreak: 3,
  ),

  // ═══ Mystic Path — Efficiency / Planning ═══
  //
  // Theme: Strategic rewards. Bonuses scale with planning effort —
  // the more you subquest and plan ahead, the more you earn.
  // Full path (9 pts): ~35% average EXP increase for strategic players.

  // 先見 (Foresight) — +10% base EXP, extends late-bonus window to 3h.
  'wiz_foresight': SkillEffectConfig(
    nodeId: 'wiz_foresight',
    tree: Job.mystic,
    baseExpMultiplier: 1.10,
    lateBonusWindowHours: 3,
  ),

  // 分割 (Split) — +15% per subquest, +25% bonus for completing all subquests.
  'wiz_split': SkillEffectConfig(
    nodeId: 'wiz_split',
    tree: Job.mystic,
    perSubquestBonus: 0.15,
    subquestCompletionBonus: 0.25,
  ),

  // 転移 (Transfer) — +15% EXP for completing tasks >24h before deadline.
  // Rewards proactive planning.
  'wiz_transfer': SkillEffectConfig(
    nodeId: 'wiz_transfer',
    tree: Job.mystic,
    earlyBonusMultiplier: 0.15,
    earlyBonusThresholdHours: 24,
  ),
};

// ━━━ Convenience helpers ━━━

/// Returns whether [id] has an effect config defined.
bool hasEffectConfig(String id) => skillEffectConfig.containsKey(id);

/// Returns the effect config for [id], or null if not found.
SkillEffectConfig? effectConfigFor(String id) => skillEffectConfig[id];

/// Returns all effect configs for the given [unlockedIds].
List<SkillEffectConfig> effectConfigsFor(Iterable<String> unlockedIds) {
  return unlockedIds
      .map((id) => skillEffectConfig[id])
      .whereType<SkillEffectConfig>()
      .toList();
}
