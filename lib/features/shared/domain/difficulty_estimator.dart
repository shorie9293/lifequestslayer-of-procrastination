import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/griffon_estimator.dart';

/// クエストタイトルから難易度ランクを推定するユーティリティクラス。
///
/// Phase 1: Sランク（最重要・緊急）→ Aランク（重要・中規模）→ Bランク（通常・軽量）
/// の順にキーワードマッチングを行う。
///
/// Phase 2: [GriffonEstimator] を用いた魔導書解析AIによる推定をサポート。
/// AI推定が利用可能な場合はそれを優先し、フォールバックとしてキーワード推定を使用する。
class DifficultyEstimator {
  DifficultyEstimator._();

  static const List<String> _sRankKeywords = [
    '本番',
    'デプロイ',
    'リリース',
    '緊急',
    '障害',
    '締切',
    '重要',
    '障害対応',
    'インシデント',
    '火消し',
    'バグ修正',
  ];

  static const List<String> _aRankKeywords = [
    '実装',
    '開発',
    '会議',
    '資料',
    '設計',
    'テスト',
    'レビュー',
    '調査',
    '分析',
    '提案',
    '計画',
    '移行',
    '報告',
    '設定',
    '構築',
    '導入',
    '検証',
    '最適化',
    'リファクタ',
    '勉強',
    '学習',
    '研修',
    '発表',
    'プレゼン',
    '修正',
    '更新',
    '予約',
    '支払い',
    '片付け',
    '整理',
  ];

  /// タイトル文字列から難易度ランクを推定する。
  ///
  /// 1. Sランクキーワードを含む → [QuestRank.S]
  /// 2. Aランクキーワードを含む、または15文字超 → [QuestRank.A]
  /// 3. それ以外 → [QuestRank.B]
  static QuestRank estimateRank(String title) {
    // Sキーワードチェック（最優先）
    for (final keyword in _sRankKeywords) {
      if (title.contains(keyword)) {
        return QuestRank.S;
      }
    }

    // Aキーワードチェック（Sキーワードがなければ）または15文字超
    if (title.length > 15) {
      return QuestRank.A;
    }
    for (final keyword in _aRankKeywords) {
      if (title.contains(keyword)) {
        return QuestRank.A;
      }
    }

    // デフォルト
    return QuestRank.B;
  }

  /// [estimateRank] と同じ推定を行うが、結果に [GriffonEstimation] を返す。
  ///
  /// キーワードベース推定のみを使う場合に使用する。
  /// estimatedMinutes は常に null、source は [EstimationSource.keyword]。
  static GriffonEstimation estimateRankWithSource(String title) {
    return GriffonEstimation.fromKeyword(estimateRank(title));
  }

  /// AI（魔導書）推定を試み、フォールバックとしてキーワード推定を使用する。
  ///
  /// [griffon] が null の場合はキーワード推定にフォールバックする。
  /// [pastTaskTitles] は AI 推定時の類似タスク判定に使用される。
  static Future<GriffonEstimation> estimateWithAI(
    String title,
    List<String> pastTaskTitles,
    GriffonEstimator? griffon,
  ) async {
    if (griffon != null) {
      try {
        return await griffon.estimate(title, pastTaskTitles);
      } catch (_) {
        // AI推定失敗時はキーワード推定にフォールバック
      }
    }
    return GriffonEstimation.fromKeyword(estimateRank(title));
  }
}
