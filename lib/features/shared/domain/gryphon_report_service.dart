import 'package:uuid/uuid.dart';
import '../../../../domain/models/gryphon_report.dart';
import '../../../../domain/models/reflection.dart';
import 'gryphon_insight_generator.dart';

/// 週次グリフォン報告エンジン。
///
/// 週間の振り返りログを集計し、AI（魔導書グリフォン）を用いて
/// 「今週の傾向」「伸びた力」「次の一手」を含む週次報告を生成する。
///
/// 使用例:
/// ```dart
/// final service = GryphonReportService(
///   insightGenerator: RealGryphonInsightGenerator(),
/// );
/// final report = await service.generateWeeklyReport(
///   weekStart: DateTime(2026, 6, 1), // 日曜日
///   reflections: weeklyReflections,
/// );
/// ```
class GryphonReportService {
  final GryphonInsightGenerator _insightGenerator;
  final Uuid _uuid;

  GryphonReportService({
    required GryphonInsightGenerator insightGenerator,
    Uuid? uuid,
  })  : _insightGenerator = insightGenerator,
        _uuid = uuid ?? const Uuid();

  /// 指定された週の振り返りからグリフォン報告を生成する。
  ///
  /// [weekStart] 対象週の日曜日（時刻部分は無視）
  /// [reflections] 全振り返りリスト（内部で週フィルタを適用）
  Future<GryphonReport> generateWeeklyReport({
    required DateTime weekStart,
    required List<Reflection> reflections,
  }) async {
    // 週の開始を日曜日 00:00:00 に正規化
    final normalizedWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd = normalizedWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    // 対象週の振り返りのみをフィルタ
    final weeklyReflections = reflections.where((r) {
      return !r.date.isBefore(normalizedWeekStart) &&
          !r.date.isAfter(weekEnd);
    }).toList();

    // 内容のある振り返りのみ抽出
    final meaningfulReflections =
        weeklyReflections.where((r) => r.content.trim().isNotEmpty).toList();

    // AI インサイト生成用のデータを準備
    final contents = meaningfulReflections.map((r) => r.content).toList();
    final taskTitles = meaningfulReflections.map((r) => r.taskId).toList();
    final selfDifficulties =
        meaningfulReflections.map((r) => r.selfDifficulty * 20).toList();

    // AI によるインサイト生成
    final insight = await _insightGenerator.generateInsight(
      contents,
      taskTitles,
      selfDifficulties,
    );

    // GryphonReport を構築
    return GryphonReport(
      id: _uuid.v4(),
      weekStartDate: normalizedWeekStart,
      weekEndDate: weekEnd,
      generatedAt: DateTime.now(),
      trends: (insight['trends'] as String?) ?? '',
      strengths: (insight['strengths'] as String?) ?? '',
      nextSteps: (insight['nextSteps'] as String?) ?? '',
      reflectionCount: weeklyReflections.length,
      reflectionIds: weeklyReflections.map((r) => r.id).toList(),
      growthScore: insight['growthScore'] as int?,
      estimationSource: (insight['growthScore'] != null &&
              meaningfulReflections.isNotEmpty)
          ? 'grffon'
          : 'keyword',
    );
  }

  /// 週の開始日（直近の日曜日 00:00:00）を取得
  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7; // DateTime.sunday = 7 → 0
    return DateTime(now.year, now.month, now.day - daysSinceSunday);
  }

  /// 指定された日付が属する週の開始日（日曜日）を取得
  static DateTime getWeekStart(DateTime date) {
    final daysSinceSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - daysSinceSunday);
  }

  /// 前週の開始日を取得
  static DateTime getPreviousWeekStart() {
    return getCurrentWeekStart().subtract(const Duration(days: 7));
  }
}
