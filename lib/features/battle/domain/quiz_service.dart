import 'dart:math';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

/// 知識クエスト（クイズ）の抽選とボーナス計算を担当するサービス。
class QuizService {
  /// 出題確率（テスト時に override しやすいよう static 変数化）
  static double probability = 0.30;

  /// 読み込まれたクイズ問題リスト（loadQuestions() で初期化）
  static List<QuizQuestion> _questions = [];

  /// 期限切れ専用クイズ問題リスト（loadOverdueQuestions() で初期化）
  static List<QuizQuestion> _overdueQuestions = [];

  /// 乱数生成器（インスタンスを再利用してパフォーマンス向上）
  static final _rng = Random();

  /// クイズ問題が読み込み済みかどうか
  static bool get isLoaded => _questions.isNotEmpty;

  /// 期限切れクイズが読み込み済みかどうか
  static bool get isOverdueLoaded => _overdueQuestions.isNotEmpty;

  /// assets/data/knowledge_quests.json からクイズ問題を読み込む。
  /// アプリ起動時に一度だけ呼び出すこと。
  static Future<void> loadQuestions() async {
    _questions = await loadQuizQuestions();
  }

  /// assets/data/overdue_quests.json から期限切れ専用クイズ問題を読み込む。
  /// アプリ起動時に一度だけ呼び出すこと。
  static Future<void> loadOverdueQuestions() async {
    _overdueQuestions = await loadOverdueQuizQuestions();
  }

  /// テスト用にクイズ問題を直接セットする。
  static void setQuestions(List<QuizQuestion> questions) {
    _questions = questions;
  }

  /// テスト用に期限切れクイズ問題を直接セットする。
  static void setOverdueQuestions(List<QuizQuestion> questions) {
    _overdueQuestions = questions;
  }

  /// 知識クエストを抽選する。
  /// 当選した場合は QuizQuestion を返し、外れた場合は null を返す。
  static QuizQuestion? drawQuizQuestion() {
    if (_questions.isEmpty) return null;
    if (_rng.nextDouble() >= probability) return null;
    return _questions[_rng.nextInt(_questions.length)];
  }

  /// 期限切れタスク用の強制クイズ（刻の番人討伐クイズ）を抽選する。
  /// overdueQuizzes プールから常に100%で出題し、
  /// 高い expBonusPercent の問題を優先的に選ぶ。
  static QuizQuestion? drawHardQuizQuestion() {
    // 期限切れ専用プールを優先、なければ通常プールから
    final pool = _overdueQuestions.isNotEmpty ? _overdueQuestions : _questions;
    if (pool.isEmpty) return null;

    // expBonusPercent の高い順にソートし、上位50%からランダム選択
    final sorted = List<QuizQuestion>.from(pool)
      ..sort((a, b) => b.expBonusPercent.compareTo(a.expBonusPercent));
    final topHalfCount = (sorted.length / 2).ceil();
    final topHalf = sorted.sublist(0, topHalfCount);
    return topHalf[_rng.nextInt(topHalf.length)];
  }

  /// 正解時のボーナスEXPを計算する。
  static int calcBonusExp(int bonusPercent, int baseExp) {
    return (baseExp * bonusPercent / 100).round();
  }
}
