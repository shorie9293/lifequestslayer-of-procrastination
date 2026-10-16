import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// クエスト別ストリーク表示用の1エントリ（不変・値オブジェクト）。
class QuestStreakEntry {
  final String taskId;
  final String title;
  final int currentStreak;
  final DateTime lastCompletedDate;

  /// 最後に完了してから経過した日数（0以上）。
  final int daysSinceLastCompletion;

  QuestStreakEntry({
    required this.taskId,
    required this.title,
    required this.currentStreak,
    required this.lastCompletedDate,
    required this.daysSinceLastCompletion,
  }) {
    if (taskId.isEmpty) {
      throw ArgumentError('taskId must not be empty');
    }
    if (currentStreak < 1) {
      throw ArgumentError('currentStreak must be >= 1');
    }
    if (daysSinceLastCompletion < 0) {
      throw ArgumentError('daysSinceLastCompletion must be >= 0');
    }
  }

  /// ボーナス閾値以上のストリークなら true。
  bool get isBonusActive => currentStreak >= QuestStreakService.bonusThreshold;

  /// ストリーク表示ラベル（例: '連続 3日'）。
  String get streakLabel => '連続 $currentStreak日';

  /// ボーナス中表示ラベル。非ボーナス時は空文字。
  String get bonusLabel => isBonusActive ? '+20% EXP' : '';

  /// 最終完了日ラベル（YYYY-MM-DD、ゼロ埋め）。
  String get lastCompletedLabel {
    final m = lastCompletedDate.month.toString().padLeft(2, '0');
    final d = lastCompletedDate.day.toString().padLeft(2, '0');
    return '${lastCompletedDate.year.toString().padLeft(4, '0')}-$m-$d';
  }
}

/// ストリーク一覧の集計結果（不変・値オブジェクト）。
class QuestStreakSummary {
  final int trackedCount;
  final int longestStreak;
  final int bonusActiveCount;

  const QuestStreakSummary({
    required this.trackedCount,
    required this.longestStreak,
    required this.bonusActiveCount,
  });

  /// 最長ストリークラベル。記録なしは '記録なし'。
  String get longestStreakLabel =>
      longestStreak <= 0 ? '記録なし' : '最長 $longestStreak日';

  /// ボーナス中表示ラベル。
  String get bonusActiveLabel => 'ボーナス中 $bonusActiveCount件';
}

/// クエスト別ストリークの構築・整列・集計（純粋・static のみ・副作用なし）。
class QuestStreakService {
  const QuestStreakService._();

  /// ボーナスが有効になるストリーク閾値。
  static const int bonusThreshold = 7;

  /// [tasks] と [streaks] から entry を構築する。
  /// streaks に無い task は除外、tasks に無い streak（未知 taskId）も除外。
  static List<QuestStreakEntry> build({
    required List<Task> tasks,
    required Map<String, TaskStreak> streaks,
    required DateTime now,
  }) {
    final entries = <QuestStreakEntry>[];
    for (final task in tasks) {
      final streak = streaks[task.id];
      if (streak == null) continue;
      final today = DateTime(now.year, now.month, now.day);
      final last = DateTime(
        streak.lastCompletedDate.year,
        streak.lastCompletedDate.month,
        streak.lastCompletedDate.day,
      );
      final diff = today.difference(last).inDays;
      entries.add(
        QuestStreakEntry(
          taskId: task.id,
          title: task.title,
          currentStreak: streak.currentStreak,
          lastCompletedDate: streak.lastCompletedDate,
          daysSinceLastCompletion: diff < 0 ? 0 : diff,
        ),
      );
    }
    return entries;
  }

  /// 明示的な安定ソート（非破壊）。
  /// currentStreak 降順 → title 昇順 → taskId 昇順。全タイでも決定的。
  static List<QuestStreakEntry> sortEntries(List<QuestStreakEntry> entries) {
    final list = entries.toList()
      ..sort((a, b) {
        final byStreak = b.currentStreak.compareTo(a.currentStreak);
        if (byStreak != 0) return byStreak;
        final byTitle = a.title.compareTo(b.title);
        if (byTitle != 0) return byTitle;
        return a.taskId.compareTo(b.taskId);
      });
    return list;
  }

  /// 集計する。空リストは trackedCount=0 / longestStreak=0 / bonusActiveCount=0。
  static QuestStreakSummary summarize(List<QuestStreakEntry> entries) {
    var longest = 0;
    var bonusActive = 0;
    for (final e in entries) {
      if (e.currentStreak > longest) longest = e.currentStreak;
      if (e.isBonusActive) bonusActive++;
    }
    return QuestStreakSummary(
      trackedCount: entries.length,
      longestStreak: longest,
      bonusActiveCount: bonusActive,
    );
  }

  /// ボーナス中の entry のみに絞り込む（非破壊）。
  static List<QuestStreakEntry> filterBonusActive(
    List<QuestStreakEntry> entries,
  ) {
    return entries.where((e) => e.isBonusActive).toList(growable: false);
  }

  /// 全角英数・全角スペースを半角へ正規化し小文字化した title 部分一致。
  /// query が空（または空白のみ）なら全件返す。
  static List<QuestStreakEntry> searchByTitle(
    List<QuestStreakEntry> entries,
    String query,
  ) {
    final q = _normalize(query);
    if (q.isEmpty) return List.of(entries);
    return entries
        .where((e) => _normalize(e.title).contains(q))
        .toList(growable: false);
  }

  static String _normalize(String input) {
    final sb = StringBuffer();
    for (final code in input.runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) {
        sb.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        sb.write(' ');
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
