import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/reflection_badge.dart';

/// 1バッジ分の進捗（分母つき）。
///
/// 完全に純粋な値オブジェクト。リポジトリには依存しない。
class ReflectionBadgeProgress {
  final ReflectionBadgeDefinition def;

  /// 現在の進捗（絶対値）。
  final int current;

  /// 達成必要数（分母）。
  final int required;

  /// プレイヤーが獲得済みか。
  final bool isUnlocked;

  ReflectionBadgeProgress({
    required this.def,
    required this.current,
    required this.required,
    required this.isUnlocked,
  }) {
    if (current < 0) {
      throw ArgumentError('current must be >= 0, got $current');
    }
    if (required < 0) {
      throw ArgumentError('required must be >= 0, got $required');
    }
  }

  /// 0.0〜1.0にクランプした進捗率。[required] <= 0 は 0.0。
  double get ratio {
    if (required <= 0) return 0.0;
    final r = current / required;
    if (r < 0.0) return 0.0;
    if (r > 1.0) return 1.0;
    return r;
  }

  /// 0〜100の整数パーセント。
  int get percent => (ratio * 100).round();

  /// 完了（current >= required かつ required > 0）か。
  bool get isComplete => required > 0 && current >= required;

  /// 残り必要数（完了済みは0）。
  int get remaining {
    final rem = required - current;
    return rem > 0 ? rem : 0;
  }

  /// 進捗ラベル（例: '3 / 5'）。
  String get progressLabel => '$current / $required';
}

/// 内省バッジコレクションの純粋ビルダー。
///
/// リポジトリ/Hiveには一切触れず、[Player] と [Reflection] の一覧のみを
/// 引数として受け取って進捗一覧を組み立てる。
class ReflectionBadgeCollection {
  ReflectionBadgeCollection._();

  /// 全バッジの進捗一覧を組み立てる。
  ///
  /// - isUnlocked は [Player.reflectionBadges] の包含で決定。
  /// - current は各バッジの進捗を純粋算出（reflections == null でも例外を投げない）。
  /// - ソート: tier昇順 → required昇順 → id昇順（安定）。
  static List<ReflectionBadgeProgress> build({
    required Player player,
    List<Reflection>? reflections,
  }) {
    final badges = player.reflectionBadges;
    final streak = _calcStreak(reflections);
    final awarenessMatches = _calcAwarenessMatches(reflections);

    final list = kAllReflectionBadges.map((def) {
      final isUnlocked = badges.contains(def.id);
      final required = kReflectionBadgeRequirements[def.id] ?? 0;
      final current = _currentFor(
        def.id,
        player: player,
        badges: badges,
        streak: streak,
        awarenessMatches: awarenessMatches,
      );
      return ReflectionBadgeProgress(
        def: def,
        current: current,
        required: required,
        isUnlocked: isUnlocked,
      );
    }).toList()
      ..sort((a, b) {
        final byTier = a.def.tier.compareTo(b.def.tier);
        if (byTier != 0) return byTier;
        final byRequired = a.required.compareTo(b.required);
        if (byRequired != 0) return byRequired;
        return a.def.id.compareTo(b.def.id);
      });
    return list;
  }

  /// バッジIDに応じた現在値の純粋算出。
  static int _currentFor(
    String id, {
    required Player player,
    required List<String> badges,
    required int streak,
    required int awarenessMatches,
  }) {
    switch (id) {
      case 'first_reflection':
      case 'reflection_novice':
      case 'reflection_adept':
      case 'reflection_sage':
      case 'reflection_master':
        return player.totalReflections;
      // コンテンツ系・streak系・self_awarenessは防御的に獲得状態で1/0を
      // 返す（カウント系の進捗は各ケースで上書きする）。
      default:
        break;
    }
    switch (id) {
      case 'streak_3':
        return _min(streak, 3);
      case 'streak_7':
        return _min(streak, 7);
      case 'streak_30':
        return _min(streak, 30);
      case 'self_awareness':
        return _min(awarenessMatches, 3);
      case 'first_insight':
      case 'deep_insight':
      case 'honest_assessor':
      default:
        // コンテンツ系は獲得済みなら1、未獲得なら0。
        return badges.contains(id) ? 1 : 0;
    }
  }

  static int _min(int a, int b) => a < b ? a : b;

  /// 日付降順から連続日数を数える（reflections が null/空なら 0）。
  /// 同日は1日として扱い、ストリークは required ベースでクランプされる。
  static int _calcStreak(List<Reflection>? reflections) {
    if (reflections == null || reflections.isEmpty) return 0;
    // 日付のみに丸めた一意な日リスト（降順）。
    final days = reflections
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    int streak = 1;
    for (int i = 1; i < days.length; i++) {
      final diff = days[i - 1].difference(days[i]);
      if (diff.inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// selfDifficulty == aiDifficultyValue の一致数（reflections が null なら 0）。
  static int _calcAwarenessMatches(List<Reflection>? reflections) {
    if (reflections == null) return 0;
    var count = 0;
    for (final r in reflections) {
      if (r.selfDifficulty == r.aiDifficultyValue) count++;
    }
    return count;
  }

  /// 獲得済みバッジ数。
  static int earnedCount(List<ReflectionBadgeProgress> list) =>
      list.where((p) => p.isUnlocked).length;

  /// tierごとにグルーピング（tier昇順のMap）。
  static Map<int, List<ReflectionBadgeProgress>> groupByTier(
    List<ReflectionBadgeProgress> list,
  ) {
    final map = <int, List<ReflectionBadgeProgress>>{};
    for (final p in list) {
      map.putIfAbsent(p.def.tier, () => []).add(p);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final k in sortedKeys) k: map[k]!};
  }

  /// サマリーラベル（例: '獲得 5 / 12'）。
  static String summaryLabel(List<ReflectionBadgeProgress> list) =>
      '獲得 ${earnedCount(list)} / ${list.length}';
}
