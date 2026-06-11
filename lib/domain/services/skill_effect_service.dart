import 'dart:math';
import 'package:rpg_todo/domain/models/skill_effects.dart';

/// Resolves and applies [SkillEffectConfig] values for a player's unlocked
/// skill tree nodes.
///
/// Usage:
/// ```dart
/// final svc = SkillEffectService(player.unlockedSkillIds);
/// exp = svc.applyBaseMultiplier(exp);
/// exp = svc.applyBonusChance(exp, rng);
/// exp = svc.applyCritical(exp, rng);
/// ```
///
/// Each method checks whether the relevant node is unlocked and applies the
/// corresponding effect.  The service is stateless beyond the unlocked set,
/// so it can be created fresh on each task completion.
class SkillEffectService {
  final Set<String> _unlockedIds;

  /// Creates a service for the given set of unlocked skill node IDs.
  SkillEffectService(Iterable<String> unlockedIds)
      : _unlockedIds = unlockedIds.toSet();

  // ━━━ Internal helpers ━━━

  bool _has(String id) => _unlockedIds.contains(id);

  SkillEffectConfig? _cfg(String id) {
    if (!_unlockedIds.contains(id)) return null;
    return skillEffectConfig[id];
  }

  // ━━━ Warrior — Speed / Crit ━━━

  /// Whether 一閃 is unlocked.
  bool get hasFlash => _has('war_flash');

  /// Apply 一閃 (war_flash): [bonusExpChance]% chance for +[bonusExpMultiplier]% EXP.
  /// Returns the bonus EXP amount (0 if chance fails or node not unlocked).
  int applyFlashBonus(int exp, Random rng) {
    final cfg = _cfg('war_flash');
    if (cfg == null || cfg.bonusExpChance <= 0) return 0;
    if (rng.nextDouble() < cfg.bonusExpChance) {
      return (exp * cfg.bonusExpMultiplier).round();
    }
    return 0;
  }

  /// Whether 連撃 is unlocked.
  bool get hasCombo => _has('war_combo');

  /// Effective EXP awarded per combo count.
  /// Base is 10; 連撃 raises it.
  int get comboExpPerCount {
    final cfg = _cfg('war_combo');
    return cfg?.comboExpPerCount ?? 10;
  }

  /// Added to the base combo multiplier step (0.10).
  /// 連撃 adds 0.05 → effective step = 0.15.
  double get comboStepBonus {
    final cfg = _cfg('war_combo');
    return cfg?.comboStepBonus ?? 0.0;
  }

  /// Whether 会心 is unlocked.
  bool get hasCritical => _has('war_critical');

  /// Apply 会心 (war_critical): [critChance]% chance for [critMultiplier]× EXP.
  /// Returns the additional EXP from the crit (0 if chance fails).
  int applyCritical(int exp, Random rng) {
    final cfg = _cfg('war_critical');
    if (cfg == null || cfg.critChance <= 0) return 0;
    if (rng.nextDouble() < cfg.critChance) {
      return (exp * (cfg.critMultiplier - 1.0)).round();
    }
    return 0;
  }

  // ━━━ Cleric — Healing / Buffs ━━━

  /// Whether 祈り is unlocked.
  bool get hasPrayer => _has('cle_prayer');

  /// Apply 祈り (cle_prayer) base EXP multiplier.
  int applyPrayerBonus(int exp) {
    final cfg = _cfg('cle_prayer');
    if (cfg == null) return exp;
    return (exp * cfg.baseExpMultiplier).round();
  }

  /// Whether 治癒 is unlocked.
  bool get hasHeal => _has('cle_heal');

  /// Penalty reduction fraction (0.0–1.0) from 治癒.
  /// E.g. 0.50 → overdue penalty halved.
  double get penaltyReduction {
    final cfg = _cfg('cle_heal');
    return cfg?.penaltyReduction ?? 0.0;
  }

  /// Whether 加護 is unlocked.
  bool get hasWard => _has('cle_ward');

  /// Apply 加護 (cle_ward) streak bonus.
  /// Returns the bonus EXP amount if [streakDays] ≥ [streakBonusMinStreak].
  int applyWardStreakBonus(int exp, int streakDays) {
    final cfg = _cfg('cle_ward');
    if (cfg == null) return 0;
    if (streakDays < cfg.streakBonusMinStreak) return 0;
    return (exp * cfg.streakBonusMultiplier).round();
  }

  /// Minimum streak days to trigger 加護 bonus.
  int get wardMinStreak {
    final cfg = _cfg('cle_ward');
    return cfg?.streakBonusMinStreak ?? 0;
  }

  // ━━━ Wizard — Efficiency / Planning ━━━

  /// Whether 先見 is unlocked.
  bool get hasForesight => _has('wiz_foresight');

  /// Apply 先見 (wiz_foresight) base EXP multiplier.
  int applyForesightBonus(int exp) {
    final cfg = _cfg('wiz_foresight');
    if (cfg == null) return exp;
    return (exp * cfg.baseExpMultiplier).round();
  }

  /// Effective late-bonus window in hours (base 1h, 先見 extends to 3h).
  int get lateBonusWindowHours {
    final cfg = _cfg('wiz_foresight');
    return cfg?.lateBonusWindowHours ?? 1;
  }

  /// Whether 分割 is unlocked.
  bool get hasSplit => _has('wiz_split');

  /// Apply 分割 (wiz_split) subquest bonuses.
  ///
  /// [subquestCount] is the total number of subquests.
  /// [allComplete] is whether all subquests are done.
  /// Returns the bonus EXP amount.
  int applySplitBonus(int exp, int subquestCount, bool allComplete) {
    final cfg = _cfg('wiz_split');
    if (cfg == null || subquestCount <= 0) return 0;
    int bonus = 0;
    // Per-subquest bonus × count
    bonus += (exp * cfg.perSubquestBonus * subquestCount).round();
    // All-complete bonus
    if (allComplete) {
      bonus += (exp * cfg.subquestCompletionBonus).round();
    }
    return bonus;
  }

  /// Whether 転移 is unlocked.
  bool get hasTransfer => _has('wiz_transfer');

  /// Apply 転移 (wiz_transfer) early completion bonus.
  ///
  /// [hoursBeforeDeadline] must be > [earlyBonusThresholdHours] to trigger.
  /// Returns the bonus EXP amount.
  int applyTransferBonus(int exp, double hoursBeforeDeadline) {
    final cfg = _cfg('wiz_transfer');
    if (cfg == null) return 0;
    if (hoursBeforeDeadline <= cfg.earlyBonusThresholdHours) return 0;
    return (exp * cfg.earlyBonusMultiplier).round();
  }

  /// Early bonus threshold in hours.
  int get earlyBonusThresholdHours {
    final cfg = _cfg('wiz_transfer');
    return cfg?.earlyBonusThresholdHours ?? 0;
  }

  // ━━━ Aggregate queries ━━━

  /// All base EXP multipliers multiplied together.
  /// Used for applying passive +% EXP from 祈り and 先見.
  double get combinedBaseMultiplier {
    double m = 1.0;
    for (final id in _unlockedIds) {
      final cfg = _cfg(id);
      if (cfg != null) m *= cfg.baseExpMultiplier;
    }
    return m;
  }

  /// Whether any valid skill tree node is unlocked.
  bool get hasAnySkill =>
      _unlockedIds.any((id) => skillEffectConfig.containsKey(id));

  /// Number of unlocked valid skill tree nodes.
  int get unlockedCount =>
      _unlockedIds.where((id) => skillEffectConfig.containsKey(id)).length;
}
