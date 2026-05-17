import 'package:rpg_todo/domain/models/task.dart';

/// クエストタイトルから難易度ランクを推定するユーティリティクラス。
///
/// Sランク（最重要・緊急）→ Aランク（重要・中規模）→ Bランク（通常・軽量）
/// の順にキーワードマッチングを行う。
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
}
