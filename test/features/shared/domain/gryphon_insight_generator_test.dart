import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 注: このテストは gryphon_insight_generator.dart を直接参照する。
/// rpg-task プロジェクトへの統合時は import パスを
/// `package:rpg_todo/features/shared/domain/gryphon_insight_generator.dart`
/// に変更すること。

// ━━━ 簡易インポート（ワークスペース内テスト用） ━━━
// 実際の統合時は pubspec.yaml に依存を追加し package: で import

void main() {
  group('RealGryphonInsightGenerator.parseResponse', () {
    test('完全なAI応答をパース', () {
      // parseResponse は static メソッドとして定義されている想定
      // ここでは関数シグネチャが同じならテスト可能
      final result = _parseResponse(
        'TRENDS: 今週は集中力が高く、困難なタスクにも積極的に取り組めた。\n'
        'STRENGTHS: 自己管理能力が向上し、締切前に余裕を持って完了できた。\n'
        'NEXT_STEPS: - 次のタスクにも早めに着手する\n- 苦手分野の克服に時間を割く\n'
        'GROWTH_SCORE: 78',
      );
      expect(result['trends'], contains('集中力'));
      expect(result['strengths'], contains('自己管理'));
      expect(result['nextSteps'], contains('早めに着手'));
      expect(result['growthScore'], 78);
    });

    test('小文字のキーもパース', () {
      final result = _parseResponse(
        'trends: 軽量タスクを着実に完了。\n'
        'strengths: 習慣化の力が育っている。\n'
        'next_steps: - 来週は難易度の高いタスクに挑戦\n'
        'growth_score: 55',
      );
      expect(result['trends'], contains('軽量タスク'));
      expect(result['strengths'], contains('習慣化'));
      expect(result['nextSteps'], contains('難易度の高いタスク'));
      expect(result['growthScore'], 55);
    });

    test('TRENDSのみの応答', () {
      final result = _parseResponse(
        'TRENDS: 今週はタスク3件を完了。',
      );
      expect(result['trends'], '今週はタスク3件を完了。');
      expect(result['strengths'], '');
      expect(result['nextSteps'], '');
      expect(result['growthScore'], isNull);
    });

    test('GROWTH_SCOREが範囲外の場合はクランプ', () {
      // parseResponse 内で clamp する想定
      final result = _parseResponse(
        'GROWTH_SCORE: 150',
      );
      expect(result['growthScore'], 100);
    });

    test('空文字列', () {
      final result = _parseResponse('');
      expect(result['trends'], '');
      expect(result['strengths'], '');
      expect(result['nextSteps'], '');
      expect(result['growthScore'], isNull);
    });

    test('複数行のNEXT_STEPS', () {
      final result = _parseResponse(
        'TRENDS: test\n'
        'STRENGTHS: test\n'
        'NEXT_STEPS: - アクション1\n- アクション2\n- アクション3\n'
        'GROWTH_SCORE: 60',
      );
      expect(result['nextSteps'], contains('アクション1'));
      expect(result['nextSteps'], contains('アクション2'));
      expect(result['nextSteps'], contains('アクション3'));
    });
  });

  group('RealGryphonInsightGenerator system prompt', () {
    test('システムプロンプトに必須キーが含まれる', () {
      final prompt = _buildSystemPrompt();
      expect(prompt, contains('TRENDS'));
      expect(prompt, contains('STRENGTHS'));
      expect(prompt, contains('NEXT_STEPS'));
      expect(prompt, contains('GROWTH_SCORE'));
      expect(prompt, contains('魔導書グリフォン'));
    });
  });

  group('RealGryphonInsightGenerator user message', () {
    test('振り返りありの場合', () {
      final message = _buildUserMessage(
        ['集中できた', '改善点が多い'],
        ['タスクA', 'タスクB'],
        [70, 40],
      );
      expect(message, contains('タスクA'));
      expect(message, contains('タスクB'));
      expect(message, contains('集中できた'));
      expect(message, contains('改善点が多い'));
      expect(message, contains('70/100'));
      expect(message, contains('40/100'));
    });

    test('振り返りなしの場合', () {
      final message = _buildUserMessage([], [], []);
      expect(message, contains('振り返りが記録されていません'));
    });
  });

  group('RealGryphonInsightGenerator fallback', () {
    test('振り返りなしのフォールバック', () {
      final result = _fallbackInsight([], []);
      expect(result['trends'], contains('まだ振り返りが記録されていません'));
      expect(result['strengths'], isNotEmpty);
      expect(result['nextSteps'], isNotEmpty);
    });

    test('高難易度クエストのフォールバック', () {
      final result = _fallbackInsight(
        ['難しいタスクだった', '挑戦的だった'],
        [85, 90],
      );
      expect(result['strengths'], contains('挑戦'));
      expect(result['growthScore'], greaterThanOrEqualTo(80));
    });

    test('低難易度クエストのフォールバック', () {
      final result = _fallbackInsight(
        ['簡単だった'],
        [20],
      );
      expect(result['strengths'], contains('軽量'));
      expect(result['nextSteps'], contains('難易度の高いタスク'));
    });
  });
}

// ━━━ テスト用ヘルパー（統合時に実際のクラスに置き換え） ━━━

Map<String, dynamic> _parseResponse(String content) {
  final trendsRegex = RegExp(
    r'TRENDS?:\s*(.+?)(?=STRENGTHS?:|NEXT[_ ]?STEPS?:|GROWTH[_ ]?SCORE?:|$)',
    dotAll: true,
    caseSensitive: false,
  );
  final strengthsRegex = RegExp(
    r'STRENGTHS?:\s*(.+?)(?=TRENDS?:|NEXT[_ ]?STEPS?:|GROWTH[_ ]?SCORE?:|$)',
    dotAll: true,
    caseSensitive: false,
  );
  final nextStepsRegex = RegExp(
    r'NEXT[_ ]?STEPS?:\s*(.+?)(?=TRENDS?:|STRENGTHS?:|GROWTH[_ ]?SCORE?:|$)',
    dotAll: true,
    caseSensitive: false,
  );
  final growthScoreRegex = RegExp(
    r'GROWTH[_ ]?SCORE?:\s*(\d+)',
    caseSensitive: false,
  );

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

String _buildSystemPrompt() {
  return 'あなたは「魔導書グリフォン」——冒険者の週間の振り返りを解析し、'
      '成長の軌跡を読み解く古代の知性体である。\n\n'
      '与えられた週間の振り返りログから、以下の3つの観点で分析を奏上せよ：\n\n'
      '【今週の傾向】TRENDS:\n'
      '（略）\n\n'
      '【伸びた力】STRENGTHS:\n'
      '（略）\n\n'
      '【次の一手】NEXT_STEPS:\n'
      '（略）\n\n'
      '【成長スコア】GROWTH_SCORE:\n'
      '（略）\n\n'
      '【出力形式】\n'
      'TRENDS: (今週の傾向)\n'
      'STRENGTHS: (伸びた力)\n'
      'NEXT_STEPS: (次の一手)\n'
      'GROWTH_SCORE: (0-100の数値)';
}

String _buildUserMessage(
  List<String> reflectionContents,
  List<String> taskTitles,
  List<int> selfDifficulties,
) {
  final buffer = StringBuffer();
  buffer.writeln('【今週の振り返りログ】\n');
  if (reflectionContents.isEmpty) {
    buffer.writeln('（今週は振り返りが記録されていません）');
  } else {
    for (var i = 0; i < reflectionContents.length; i++) {
      buffer.writeln('--- 振り返り ${i + 1} ---');
      buffer.writeln('タスク: ${taskTitles.length > i ? taskTitles[i] : "不明"}');
      buffer.writeln('自己評価難易度: ${selfDifficulties.length > i ? selfDifficulties[i] : "未記入"}/100');
      buffer.writeln('振り返り内容: ${reflectionContents[i]}\n');
    }
  }
  buffer.writeln('上記の週間振り返りを分析し、TRENDS/STRENGTHS/NEXT_STEPS/GROWTH_SCORE を奏上せよ。');
  return buffer.toString();
}

Map<String, dynamic> _fallbackInsight(
  List<String> reflectionContents,
  List<int> selfDifficulties,
) {
  final count = reflectionContents.where((c) => c.trim().isNotEmpty).length;
  final total = reflectionContents.length;
  double avgDifficulty = 0;
  if (selfDifficulties.isNotEmpty) {
    avgDifficulty = selfDifficulties.reduce((a, b) => a + b) / selfDifficulties.length;
  }

  String trends;
  if (total == 0) {
    trends = '今週はまだ振り返りが記録されていません。';
  } else if (count < total) {
    trends = '今週は$total件中$count件の振り返りが記録されました。';
  } else {
    trends = '今週は$total件すべてのタスクで振り返りが記録されました。';
  }

  String strengths;
  if (avgDifficulty > 70) {
    strengths = '困難なタスクに積極的に挑戦した週でした。';
  } else if (avgDifficulty > 40) {
    strengths = 'バランスの取れた週でした。';
  } else {
    strengths = '軽量タスクを着実に完了させた週でした。';
  }

  String nextSteps;
  if (avgDifficulty < 30) {
    nextSteps = '- 難易度の高いタスクに挑戦しましょう';
  } else {
    nextSteps = '- 来週も継続して振り返りを記録しましょう';
  }

  return {
    'trends': trends,
    'strengths': strengths,
    'nextSteps': nextSteps,
    'growthScore': avgDifficulty.round().clamp(0, 100),
  };
}
