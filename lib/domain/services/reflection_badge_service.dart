import 'dart:math';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/reflection_badge.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// 内省バッジの判定・付与を担当するサービス。
///
/// [TitleService] と同様のパターンで、プレイヤーの状態と振り返り履歴を
/// 照合してバッジ獲得を判定する。
class ReflectionBadgeService {
  /// 全バッジをチェックし、新たに獲得したバッジをプレイヤーに追加する。
  /// 獲得したバッジがあれば、[bonusMessages] にメッセージを追加する。
  ///
  /// [repository] は [requiresRepository]=true のバッジ判定にのみ使用される。
  /// null の場合、リポジトリ不要なバッジのみ判定される。
  ///
  /// [latestReflection] は直近に保存された振り返り。
  /// コンテンツ系バッジ（first_insight, deep_insight, honest_assessor）の
  /// 判定に使用される。
  static Future<void> checkBadges(
    Player player,
    List<String> bonusMessages, {
    ReflectionRepository? repository,
    Reflection? latestReflection,
  }) async {
    // リポジトリが必要なバッジのために、振り返り一覧を先に取得
    List<Reflection>? allReflections;
    if (repository != null) {
      allReflections = await repository.getAll();
    }

    for (final def in kAllReflectionBadges) {
      await _unlockBadge(player, def, bonusMessages,
          repository: repository, allReflections: allReflections,
          latestReflection: latestReflection);
    }
  }

  /// 単一バッジの獲得判定。
  static Future<void> _unlockBadge(
    Player player,
    ReflectionBadgeDefinition def,
    List<String> messages, {
    ReflectionRepository? repository,
    List<Reflection>? allReflections,
    Reflection? latestReflection,
  }) async {
    // 既に獲得済みならスキップ
    if (player.reflectionBadges.contains(def.id)) return;

    final bool earned;
    switch (def.id) {
      // ── カウント系（Playerフィールドで判定） ──
      case 'first_reflection':
        earned = player.totalReflections >= 1;
      case 'reflection_novice':
        earned = player.totalReflections >= 5;
      case 'reflection_adept':
        earned = player.totalReflections >= 20;
      case 'reflection_sage':
        earned = player.totalReflections >= 50;
      case 'reflection_master':
        earned = player.totalReflections >= 100;

      // ── コンテンツ系（直近の振り返り内容で判定） ──
      case 'first_insight':
        earned = latestReflection != null &&
            latestReflection.content.length >= 50;
      case 'deep_insight':
        earned = latestReflection != null &&
            latestReflection.content.length >= 100;

      // ── 自己評価系 ──
      case 'honest_assessor':
        earned = latestReflection != null &&
            latestReflection.selfDifficulty >= 4;

      // ── リポジトリ系（振り返り履歴全体を走査） ──
      case 'streak_3':
        earned = _checkStreak(allReflections, 3);
      case 'streak_7':
        earned = _checkStreak(allReflections, 7);
      case 'streak_30':
        earned = _checkStreak(allReflections, 30);
      case 'self_awareness':
        earned = _checkSelfAwareness(allReflections, 3);

      default:
        earned = false;
    }

    if (earned) {
      player.reflectionBadges.add(def.id);
      messages.add('🏅 内省バッジ獲得：${def.icon} ${def.name}');
    }
  }

  /// 連続日数 [requiredDays] を達成しているか。
  static bool _checkStreak(List<Reflection>? reflections, int requiredDays) {
    if (reflections == null || reflections.isEmpty) return false;
    if (reflections.length < requiredDays) return false;

    // 日付降順にソート
    final sorted = List<Reflection>.from(reflections)
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 1;
    for (int i = 1; i < sorted.length && i < requiredDays; i++) {
      final diff = sorted[i - 1].date.difference(sorted[i].date);
      // 同日または翌日なら連続とみなす
      if (diff.inDays <= 1 &&
          !_isSameDay(sorted[i - 1].date, sorted[i].date)) {
        streak++;
      } else if (!_isSameDay(sorted[i - 1].date, sorted[i].date)) {
        break;
      }
    }
    return streak >= requiredDays;
  }

  /// [requiredMatches] 回以上、AI難易度と自己評価が一致しているか。
  static bool _checkSelfAwareness(
      List<Reflection>? reflections, int requiredMatches) {
    if (reflections == null || reflections.length < requiredMatches) {
      return false;
    }

    int matchCount = 0;
    for (final r in reflections) {
      if (r.selfDifficulty == r.aiDifficultyValue) {
        matchCount++;
        if (matchCount >= requiredMatches) return true;
      }
    }
    return false;
  }

  /// 同日判定。
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 各バッジの現在進捗を返す。
  ///
  /// [allReflections] が null の場合、リポジトリ系バッジの進捗は暫定値になる。
  static Future<
      List<({
        ReflectionBadgeDefinition def,
        int progress,
        bool isUnlocked,
      })>> getBadgeProgressList(
    Player player, {
    ReflectionRepository? repository,
  }) async {
    List<Reflection>? allReflections;
    if (repository != null) {
      allReflections = await repository.getAll();
    }

    return kAllReflectionBadges.map((def) {
      final isUnlocked = player.reflectionBadges.contains(def.id);
      final progress = _getProgress(def, player, allReflections);
      return (def: def, progress: progress, isUnlocked: isUnlocked);
    }).toList();
  }

  /// 単一バッジの進捗値（分母を考慮しない絶対値）。
  static int _getProgress(
    ReflectionBadgeDefinition def,
    Player player,
    List<Reflection>? allReflections,
  ) {
    switch (def.id) {
      case 'first_reflection':
        return min(player.totalReflections, 1);
      case 'reflection_novice':
        return min(player.totalReflections, 5);
      case 'reflection_adept':
        return min(player.totalReflections, 20);
      case 'reflection_sage':
        return min(player.totalReflections, 50);
      case 'reflection_master':
        return min(player.totalReflections, 100);
      case 'first_insight':
      case 'deep_insight':
      case 'honest_assessor':
        // コンテンツ系は獲得済みなら1、未獲得なら0
        return player.reflectionBadges.contains(def.id) ? 1 : 0;
      case 'streak_3':
        return _calcStreakProgress(allReflections, 3);
      case 'streak_7':
        return _calcStreakProgress(allReflections, 7);
      case 'streak_30':
        return _calcStreakProgress(allReflections, 30);
      case 'self_awareness':
        return _calcAwarenessProgress(allReflections, 3);
      default:
        return 0;
    }
  }

  static int _calcStreakProgress(List<Reflection>? reflections, int maxDays) {
    if (reflections == null || reflections.isEmpty) return 0;
    final sorted = List<Reflection>.from(reflections)
      ..sort((a, b) => b.date.compareTo(a.date));
    int streak = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i - 1].date.difference(sorted[i].date);
      if (diff.inDays <= 1 &&
          !_isSameDay(sorted[i - 1].date, sorted[i].date)) {
        streak++;
      } else if (!_isSameDay(sorted[i - 1].date, sorted[i].date)) {
        break;
      }
    }
    return min(streak, maxDays);
  }

  static int _calcAwarenessProgress(
      List<Reflection>? reflections, int maxMatches) {
    if (reflections == null) return 0;
    int matchCount = 0;
    for (final r in reflections) {
      if (r.selfDifficulty == r.aiDifficultyValue) {
        matchCount++;
      }
    }
    return min(matchCount, maxMatches);
  }
}
