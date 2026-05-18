import 'package:rpg_todo/domain/models/task.dart';

/// 推定結果の出所を示す列挙型。
enum EstimationSource {
  /// キーワードベースのローカル推定（Phase 1）
  keyword,

  /// AI（魔導書）による推定（Phase 2）
  grffon,
}

/// AI推定の結果を保持する値オブジェクト。
class GriffonEstimation {
  final QuestRank rank;
  final int? estimatedMinutes;
  final EstimationSource source;

  const GriffonEstimation({
    required this.rank,
    this.estimatedMinutes,
    this.source = EstimationSource.grffon,
  });

  /// キーワード推定からの生成用ファクトリ
  factory GriffonEstimation.fromKeyword(QuestRank rank) {
    return GriffonEstimation(
      rank: rank,
      estimatedMinutes: null,
      source: EstimationSource.keyword,
    );
  }
}

/// 魔導書解析AI — 過去のタスク履歴から難易度と見積もり時間を推定する。
///
/// 具象実装は LLM API（DeepSeek 等）を呼び出す [RealGriffonEstimator]、
/// テスト用の [FakeGriffonEstimator] はテストファイルに定義する。
abstract class GriffonEstimator {
  /// タスクタイトルと過去のタスク履歴から推定結果を返す。
  ///
  /// [title] 推定対象のタスクタイトル。
  /// [pastTaskTitles] 過去に完了したタスクのタイトル一覧（類似度判定に使用）。
  Future<GriffonEstimation> estimate(
    String title,
    List<String> pastTaskTitles,
  );
}
