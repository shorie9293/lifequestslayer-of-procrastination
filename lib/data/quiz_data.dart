import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 知識クエストのクイズ問題モデル
class QuizQuestion {
  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final int expBonusPercent; // 正解時のボーナスEXP (base exp に対する %)
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.expBonusPercent,
    this.explanation,
  });

  /// JSONマップから QuizQuestion を生成するファクトリコンストラクタ
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      choices: List<String>.from(json['choices'] as List),
      correctIndex: json['correctIndex'] as int,
      expBonusPercent: json['expBonusPercent'] as int,
      explanation: json['explanation'] as String?,
    );
  }
}

/// assets/data/knowledge_quests.json からクイズ問題を読み込む。
/// アプリ起動時に一度だけ呼び出し、結果をキャッシュする想定。
Future<List<QuizQuestion>> loadQuizQuestions() async {
  final jsonString = await rootBundle.loadString('assets/data/knowledge_quests.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
  return jsonList.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)).toList();
}
