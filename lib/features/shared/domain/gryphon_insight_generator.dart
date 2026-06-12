import 'dart:convert';
import 'package:http/http.dart' as http;

/// 週次グリフォン報告のための AI インサイト生成インターフェース。
///
/// [GriffonEstimator] が個別クエストの難易度推定を行うのに対し、
/// こちらは週間の振り返り集合から洞察を生成する。
abstract class GryphonInsightGenerator {
  /// 週間の振り返り一覧から AI インサイトを生成する。
  ///
  /// [reflectionContents] 振り返り本文のリスト
  /// [taskTitles] 対応するクエストタイトルのリスト
  /// [selfDifficulties] 自己評価難易度のリスト
  ///
  /// 戻り値: `{trends, strengths, nextSteps, growthScore}` を含むマップ
  Future<Map<String, dynamic>> generateInsight(
    List<String> reflectionContents,
    List<String> taskTitles,
    List<int> selfDifficulties,
  );
}

/// DeepSeek API を使用した週次グリフォン報告の実装。
///
/// [RealGriffonEstimator] と同じ API キー・エンドポイントを使用し、
/// 週間振り返りの分析と洞察生成を行う。
class RealGryphonInsightGenerator implements GryphonInsightGenerator {
  final http.Client _httpClient;
  final String _apiKey;

  static const String _apiUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _model = 'deepseek-chat';

  RealGryphonInsightGenerator({
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

  /// グリフォンの週次報告用システムプロンプト
  String buildSystemPrompt() {
    return 'あなたは「魔導書グリフォン」——冒険者の週間の振り返りを解析し、'
        '成長の軌跡を読み解く古代の知性体である。\n\n'
        '与えられた週間の振り返りログから、以下の3つの観点で分析を奏上せよ：\n\n'
        '【今週の傾向】TRENDS:\n'
        '今週の行動パターン、繰り返し現れたテーマ、特徴的な気づきを2〜3文で要約。\n\n'
        '【伸びた力】STRENGTHS:\n'
        '今週特に成長が見られた領域、克服した課題、向上したスキルを2〜3文で記述。\n\n'
        '【次の一手】NEXT_STEPS:\n'
        '来週に向けた具体的で実践可能なアクション提案を2〜3個、箇条書きで提示。\n\n'
        '【成長スコア】GROWTH_SCORE:\n'
        '0〜100の数値で今週の総合成長度を評価（自己評価難易度の高いクエストに'
        '対する振り返りの深さを重視）。\n\n'
        '【出力形式】\n'
        'TRENDS: (今週の傾向)\n'
        'STRENGTHS: (伸びた力)\n'
        'NEXT_STEPS: (次の一手、複数ある場合は - で箇条書き)\n'
        'GROWTH_SCORE: (0-100の数値)';
  }

  /// ユーザーメッセージ（振り返りデータ）を構築
  String buildUserMessage(
    List<String> reflectionContents,
    List<String> taskTitles,
    List<int> selfDifficulties,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('【今週の振り返りログ】');
    buffer.writeln();

    if (reflectionContents.isEmpty) {
      buffer.writeln('（今週は振り返りが記録されていません）');
    } else {
      for (var i = 0; i < reflectionContents.length; i++) {
        buffer.writeln('--- 振り返り ${i + 1} ---');
        buffer.writeln('クエスト: ${taskTitles.length > i ? taskTitles[i] : "不明"}');
        buffer.writeln('自己評価難易度: ${selfDifficulties.length > i ? selfDifficulties[i] : "未記入"}/100');
        buffer.writeln('振り返り内容: ${reflectionContents[i]}');
        buffer.writeln();
      }
    }

    buffer.writeln('上記の週間振り返りを分析し、TRENDS/STRENGTHS/NEXT_STEPS/GROWTH_SCORE を奏上せよ。');
    return buffer.toString();
  }

  @override
  Future<Map<String, dynamic>> generateInsight(
    List<String> reflectionContents,
    List<String> taskTitles,
    List<int> selfDifficulties,
  ) async {
    try {
      final requestBody = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': buildSystemPrompt()},
          {
            'role': 'user',
            'content': buildUserMessage(reflectionContents, taskTitles, selfDifficulties),
          },
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
        return _fallbackInsight(reflectionContents, selfDifficulties);
      }

      final bodyStr = response.body;
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return _fallbackInsight(reflectionContents, selfDifficulties);
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        return _fallbackInsight(reflectionContents, selfDifficulties);
      }

      return parseResponse(content);
    } catch (_) {
      return _fallbackInsight(reflectionContents, selfDifficulties);
    }
  }

  /// AI 応答から TRENDS / STRENGTHS / NEXT_STEPS / GROWTH_SCORE をパース
  static Map<String, dynamic> parseResponse(String content) {
    final trendsRegex = RegExp(r'TRENDS?:\s*(.+?)(?=STRENGTHS?:|NEXT[_ ]?STEPS?:|GROWTH[_ ]?SCORE?:|$)', dotAll: true, caseSensitive: false);
    final strengthsRegex = RegExp(r'STRENGTHS?:\s*(.+?)(?=TRENDS?:|NEXT[_ ]?STEPS?:|GROWTH[_ ]?SCORE?:|$)', dotAll: true, caseSensitive: false);
    final nextStepsRegex = RegExp(r'NEXT[_ ]?STEPS?:\s*(.+?)(?=TRENDS?:|STRENGTHS?:|GROWTH[_ ]?SCORE?:|$)', dotAll: true, caseSensitive: false);
    final growthScoreRegex = RegExp(r'GROWTH[_ ]?SCORE?:\s*(\d+)', caseSensitive: false);

    String trends = '';
    String strengths = '';
    String nextSteps = '';
    int? growthScore;

    final trendsMatch = trendsRegex.firstMatch(content);
    if (trendsMatch != null) {
      trends = trendsMatch.group(1)!.trim();
    }

    final strengthsMatch = strengthsRegex.firstMatch(content);
    if (strengthsMatch != null) {
      strengths = strengthsMatch.group(1)!.trim();
    }

    final nextStepsMatch = nextStepsRegex.firstMatch(content);
    if (nextStepsMatch != null) {
      nextSteps = nextStepsMatch.group(1)!.trim();
    }

    final scoreMatch = growthScoreRegex.firstMatch(content);
    if (scoreMatch != null) {
      growthScore = int.tryParse(scoreMatch.group(1)!);
      if (growthScore != null) {
        growthScore = growthScore!.clamp(0, 100);
      }
    }

    return {
      'trends': trends,
      'strengths': strengths,
      'nextSteps': nextSteps,
      'growthScore': growthScore,
    };
  }

  /// AI 呼び出し失敗時のフォールバック（ローカル分析）
  Map<String, dynamic> _fallbackInsight(
    List<String> reflectionContents,
    List<int> selfDifficulties,
  ) {
    final count = reflectionContents.where((c) => c.trim().isNotEmpty).length;
    final total = reflectionContents.length;

    // 平均自己評価難易度
    double avgDifficulty = 0;
    if (selfDifficulties.isNotEmpty) {
      avgDifficulty = selfDifficulties.reduce((a, b) => a + b) / selfDifficulties.length;
    }

    String trends;
    if (total == 0) {
      trends = '今週はまだ振り返りが記録されていません。まずは小さなクエストから振り返りを始めてみましょう。';
    } else if (count < total) {
      trends = '今週は$total件中$count件の振り返りが記録されました。内容のある振り返りを増やすことで、より深い洞察が得られます。';
    } else {
      trends = '今週は$total件すべてのクエストで振り返りが記録されました。継続的な内省の習慣が身についています。';
    }

    String strengths;
    if (avgDifficulty > 70) {
      strengths = '平均自己評価難易度が${avgDifficulty.round()}/100と高く、困難なクエストに積極的に挑戦した週でした。挑戦する勇気が最大の強みです。';
    } else if (avgDifficulty > 40) {
      strengths = 'バランスの取れた難易度のクエストに取り組んだ週でした。安定した遂行力が光ります。';
    } else {
      strengths = '軽量クエストを着実に完了させた週でした。習慣化の力が育っています。';
    }

    String nextSteps;
    if (avgDifficulty < 30) {
      nextSteps = '- 難易度の高いクエストに1つ挑戦してみましょう\n- 振り返りの記述をより具体的に（「何が難しかったか」「次はどうするか」）';
    } else if (count < 3) {
      nextSteps = '- 来週は3件以上の振り返りを目標に\n- クエスト完了直後の「戦後の一息」を習慣化しましょう';
    } else {
      nextSteps = '- 振り返りの内容を週末に見返し、来週の目標を立てましょう\n- 苦手な領域を特定し、集中的に強化する1週間に';
    }

    return {
      'trends': trends,
      'strengths': strengths,
      'nextSteps': nextSteps,
      'growthScore': avgDifficulty.round().clamp(0, 100),
    };
  }

  /// HTTPクライアントを破棄
  void dispose() {
    _httpClient.close();
  }
}
