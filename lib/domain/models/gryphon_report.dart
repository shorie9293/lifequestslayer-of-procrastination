/// 週次グリフォン報告の結果モデル。
///
/// 週間の振り返りログを魔導書グリフォンが解析し、
/// 「今週の傾向」「伸びた力」「次の一手」を奏上する。
class GryphonReport {
  final String id;

  /// 対象週の開始日（日曜日 00:00:00）
  final DateTime weekStartDate;

  /// 対象週の終了日（土曜日 23:59:59）
  final DateTime weekEndDate;

  /// レポート生成日時
  final DateTime generatedAt;

  /// 今週の傾向 — 週間の行動パターンや気づきの要約
  final String trends;

  /// 伸びた力 — 成長が見られた領域や強化された能力
  final String strengths;

  /// 次の一手 — 来週に向けた具体的なアクション提案
  final String nextSteps;

  /// レポート生成に使用した振り返りエントリ数
  final int reflectionCount;

  /// 分析に使用した振り返りエントリのID一覧
  final List<String> reflectionIds;

  /// AI推定による総合成長スコア（0-100）
  /// nullの場合はAI推定未実施
  final int? growthScore;

  /// AI推定のソース（grffon=AI推定, keyword=ローカル推定）
  final String estimationSource;

  const GryphonReport({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.generatedAt,
    required this.trends,
    required this.strengths,
    required this.nextSteps,
    this.reflectionCount = 0,
    this.reflectionIds = const [],
    this.growthScore,
    this.estimationSource = 'grffon',
  });

  /// AI推定による生成か
  bool get isAIGenerated => estimationSource == 'grffon';

  /// レポートが実質的な内容を持つか
  bool get hasContent =>
      trends.isNotEmpty || strengths.isNotEmpty || nextSteps.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekStartDate': weekStartDate.toIso8601String(),
        'weekEndDate': weekEndDate.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'trends': trends,
        'strengths': strengths,
        'nextSteps': nextSteps,
        'reflectionCount': reflectionCount,
        'reflectionIds': reflectionIds,
        'growthScore': growthScore,
        'estimationSource': estimationSource,
      };

  factory GryphonReport.fromJson(Map<String, dynamic> json) {
    return GryphonReport(
      id: json['id'] as String,
      weekStartDate: DateTime.parse(json['weekStartDate'] as String),
      weekEndDate: DateTime.parse(json['weekEndDate'] as String),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      trends: json['trends'] as String? ?? '',
      strengths: json['strengths'] as String? ?? '',
      nextSteps: json['nextSteps'] as String? ?? '',
      reflectionCount: json['reflectionCount'] as int? ?? 0,
      reflectionIds:
          (json['reflectionIds'] as List<dynamic>?)?.cast<String>() ?? [],
      growthScore: json['growthScore'] as int?,
      estimationSource: json['estimationSource'] as String? ?? 'grffon',
    );
  }

  @override
  String toString() =>
      'GryphonReport(id=$id, week=${weekStartDate.toIso8601String()}, '
      'reflections=$reflectionCount, ai=$isAIGenerated)';
}
