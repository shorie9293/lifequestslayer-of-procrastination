import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rpg_todo/features/shared/domain/griffon_estimator.dart';
import 'package:rpg_todo/features/shared/domain/difficulty_estimator.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// DeepSeek APIを使用した魔導書解析推定サービスの実装。
///
/// 過去のクエスト履歴から類似クエストを分析し、
/// 難易度ランクと見積もり時間をAIが推定する。
///
/// 環境変数 DEEPSEEK_API_KEY からAPIキーを取得する。
class RealGriffonEstimator implements GriffonEstimator {
  final http.Client _httpClient;
  final String _apiKey;

  static const String _apiUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _model = 'deepseek-chat';

  RealGriffonEstimator({
    http.Client? httpClient,
    String? apiKey,
  })  : _httpClient = httpClient ?? http.Client(),
        _apiKey = apiKey ?? _readApiKey();

  static String _readApiKey() {
    const key = String.fromEnvironment('DEEPSEEK_API_KEY');
    if (key.isEmpty) {
      return 'dev-dummy-key';
    }
    return key;
  }

  /// 魔導書のシステムプロンプトを構築する
  String buildSystemPrompt() {
    return 'あなたは「魔導書（グリフォン）」——過去のクエスト履歴を解析し、'
        '新たなクエストの難易度を予見する古代の知性体である。\n\n'
        '与えられたクエストタイトルと過去のクエスト履歴から、'
        '適切な難易度ランク（S/A/B）と見積もり所要時間（分）を推定せよ。\n\n'
        '【難易度基準】\n'
        '- Sランク: 本番/緊急/障害/締切に関わる最重要クエスト（所要60〜180分）\n'
        '- Aランク: 実装/設計/分析など専門性を要する中規模クエスト（所要30〜90分）\n'
        '- Bランク: 日常的な軽量クエスト（所要5〜30分）\n\n'
        '【出力形式】\n'
        'RANK: (S|A|B)\n'
        'MINUTES: (数値)\n'
        'REASON: (推定理由を一言)';
  }

  /// ユーザーメッセージを構築する
  String buildUserMessage(String title, List<String> pastTaskTitles) {
    final pastTasksStr = pastTaskTitles.isNotEmpty
        ? pastTaskTitles.map((t) => '- $t').join('\n')
        : '（過去のクエスト履歴なし）';
    return '【新規クエスト】$title\n\n'
        '【過去の完了クエスト】\n$pastTasksStr\n\n'
        '上記の新規クエストの難易度と見積もり時間を推定せよ。';
  }

  @override
  Future<GriffonEstimation> estimate(
    String title,
    List<String> pastTaskTitles,
  ) async {
    try {
      final requestBody = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': buildSystemPrompt()},
          {'role': 'user', 'content': buildUserMessage(title, pastTaskTitles)},
        ],
      });

      final response = await _httpClient.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        return _fallbackEstimation(title);
      }

      final bodyStr = response.body;
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return _fallbackEstimation(title);
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        return _fallbackEstimation(title);
      }

      return parseResponse(content);
    } catch (_) {
      return _fallbackEstimation(title);
    }
  }

  /// DeepSeekの応答からランクと見積もり時間をパースする（テスト用に公開）
  static GriffonEstimation parseResponse(String content) {
    final rankRegex = RegExp(r'RANK:\s*(S|A|B)', caseSensitive: false);
    final minutesRegex = RegExp(r'MINUTES:\s*(\d+)', caseSensitive: false);

    final rankMatch = rankRegex.firstMatch(content);
    final minutesMatch = minutesRegex.firstMatch(content);

    QuestRank rank = QuestRank.B;
    if (rankMatch != null) {
      switch (rankMatch.group(1)!.toUpperCase()) {
        case 'S':
          rank = QuestRank.S;
        case 'A':
          rank = QuestRank.A;
      }
    }

    int? estimatedMinutes;
    if (minutesMatch != null) {
      estimatedMinutes = int.tryParse(minutesMatch.group(1)!);
    }

    return GriffonEstimation(
      rank: rank,
      estimatedMinutes: estimatedMinutes,
      source: EstimationSource.grffon,
    );
  }

  /// API呼び出し失敗時のフォールバック推定（キーワードベース）
  GriffonEstimation _fallbackEstimation(String title) {
    return GriffonEstimation.fromKeyword(
      DifficultyEstimator.estimateRank(title),
    );
  }

  /// HTTPクライアントを破棄する
  void dispose() {
    _httpClient.close();
  }
}
