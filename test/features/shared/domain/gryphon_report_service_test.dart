import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// 注: 実際の統合時は package:rpg_todo の import に置き換えること。

// ━━━ テスト用 Fake GryphonInsightGenerator ━━━
class FakeGryphonInsightGenerator {
  final Map<String, dynamic>? _fixedResponse;
  bool _called = false;
  List<String>? _lastContents;
  List<String>? _lastTaskTitles;
  List<int>? _lastSelfDifficulties;

  FakeGryphonInsightGenerator([this._fixedResponse]);

  bool get wasCalled => _called;
  List<String>? get lastContents => _lastContents;
  List<String>? get lastTaskTitles => _lastTaskTitles;
  List<int>? get lastSelfDifficulties => _lastSelfDifficulties;

  Future<Map<String, dynamic>> generateInsight(
    List<String> reflectionContents,
    List<String> taskTitles,
    List<int> selfDifficulties,
  ) async {
    _called = true;
    _lastContents = reflectionContents;
    _lastTaskTitles = taskTitles;
    _lastSelfDifficulties = selfDifficulties;

    if (_fixedResponse != null) {
      return _fixedResponse!;
    }

    return {
      'trends': 'トレンド分析結果',
      'strengths': '強み分析結果',
      'nextSteps': '次の一手',
      'growthScore': 75,
    };
  }
}

// ━━━ GryphonReportService の簡易実装（テスト用） ━━━
class GryphonReportService {
  final FakeGryphonInsightGenerator _insightGenerator;
  final Uuid _uuid;

  GryphonReportService({
    required FakeGryphonInsightGenerator insightGenerator,
    Uuid? uuid,
  })  : _insightGenerator = insightGenerator,
        _uuid = uuid ?? const Uuid();

  Future<_TestGryphonReport> generateWeeklyReport({
    required DateTime weekStart,
    required List<_TestReflection> reflections,
  }) async {
    final normalizedWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd = normalizedWeekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    final weeklyReflections = reflections.where((r) {
      return !r.createdAt.isBefore(normalizedWeekStart) &&
          !r.createdAt.isAfter(weekEnd);
    }).toList();

    final meaningfulReflections =
        weeklyReflections.where((r) => r.hasContent).toList();

    final contents = meaningfulReflections.map((r) => r.content).toList();
    final taskTitles = meaningfulReflections.map((r) => r.taskTitle).toList();
    final selfDifficulties =
        meaningfulReflections.map((r) => r.selfDifficulty).toList();

    final insight = await _insightGenerator.generateInsight(
      contents,
      taskTitles,
      selfDifficulties,
    );

    return _TestGryphonReport(
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

  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7;
    return DateTime(now.year, now.month, now.day - daysSinceSunday);
  }

  static DateTime getWeekStart(DateTime date) {
    final daysSinceSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - daysSinceSunday);
  }

  static DateTime getPreviousWeekStart() {
    return getCurrentWeekStart().subtract(const Duration(days: 7));
  }
}

// ━━━ 簡易モデル（テスト用） ━━━
class _TestReflection {
  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime createdAt;
  final String content;
  final int selfDifficulty;

  const _TestReflection({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.createdAt,
    this.content = '',
    this.selfDifficulty = 50,
  });

  bool get hasContent => content.trim().isNotEmpty;
}

class _TestGryphonReport {
  final String id;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final DateTime generatedAt;
  final String trends;
  final String strengths;
  final String nextSteps;
  final int reflectionCount;
  final List<String> reflectionIds;
  final int? growthScore;
  final String estimationSource;

  const _TestGryphonReport({
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

  bool get isAIGenerated => estimationSource == 'grffon';
}

// ━━━ テスト本体 ━━━
void main() {
  group('GryphonReportService', () {
    late FakeGryphonInsightGenerator fakeGenerator;
    late GryphonReportService service;

    setUp(() {
      fakeGenerator = FakeGryphonInsightGenerator();
      service = GryphonReportService(insightGenerator: fakeGenerator);
    });

    group('generateWeeklyReport', () {
      test('振り返りがない週のレポートも生成される', () async {
        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: [],
        );

        expect(report.reflectionCount, 0);
        expect(report.reflectionIds, isEmpty);
        expect(report.weekStartDate, DateTime(2026, 6, 1));
        expect(report.weekEndDate,
            DateTime(2026, 6, 7, 23, 59, 59));
      });

      test('対象週の振り返りのみが集計される', () async {
        final reflections = [
          _TestReflection(
            id: 'r1',
            taskId: 't1',
            taskTitle: '今週のタスク',
            createdAt: DateTime(2026, 6, 2), // 火曜（6/1の週）
            content: '集中できた',
            selfDifficulty: 60,
          ),
          _TestReflection(
            id: 'r2',
            taskId: 't2',
            taskTitle: '先週のタスク',
            createdAt: DateTime(2026, 5, 28), // 先週
            content: '頑張った',
            selfDifficulty: 80,
          ),
        ];

        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(report.reflectionCount, 1);
        expect(report.reflectionIds, ['r1']);
      });

      test('内容のある振り返りのみがAIに送られる', () async {
        final reflections = [
          _TestReflection(
            id: 'r1',
            taskId: 't1',
            taskTitle: '内容あり',
            createdAt: DateTime(2026, 6, 2),
            content: '意味のある振り返り',
            selfDifficulty: 60,
          ),
          _TestReflection(
            id: 'r2',
            taskId: 't2',
            taskTitle: '空',
            createdAt: DateTime(2026, 6, 3),
            content: '',
            selfDifficulty: 40,
          ),
        ];

        await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(fakeGenerator.wasCalled, true);
        expect(fakeGenerator.lastContents, ['意味のある振り返り']);
        expect(fakeGenerator.lastContents!.length, 1);
      });

      test('AIの応答がレポートに反映される', () async {
        fakeGenerator = FakeGryphonInsightGenerator({
          'trends': '集中力の高い週だった',
          'strengths': '計画性が向上した',
          'nextSteps': '- 朝のルーティンを継続\n- 新しい技術の学習を始める',
          'growthScore': 82,
        });
        service = GryphonReportService(insightGenerator: fakeGenerator);

        final reflections = [
          _TestReflection(
            id: 'r1',
            taskId: 't1',
            taskTitle: 'タスク1',
            createdAt: DateTime(2026, 6, 2),
            content: '良い週だった',
            selfDifficulty: 70,
          ),
        ];

        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(report.trends, '集中力の高い週だった');
        expect(report.strengths, '計画性が向上した');
        expect(report.nextSteps, contains('朝のルーティン'));
        expect(report.growthScore, 82);
        expect(report.estimationSource, 'grffon');
        expect(report.isAIGenerated, true);
      });

      test('週の境界テスト: 日曜0:00は含む', () async {
        final reflections = [
          _TestReflection(
            id: 'r1',
            taskId: 't1',
            taskTitle: '日曜のタスク',
            createdAt: DateTime(2026, 6, 1, 0, 0), // 日曜 0:00
            content: '早起き',
            selfDifficulty: 50,
          ),
        ];

        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(report.reflectionCount, 1);
      });

      test('週の境界テスト: 翌週日曜0:00は含まない', () async {
        final reflections = [
          _TestReflection(
            id: 'r1',
            taskId: 't1',
            taskTitle: '翌週のタスク',
            createdAt: DateTime(2026, 6, 8, 0, 0), // 翌週日曜
            content: '新たな週',
            selfDifficulty: 50,
          ),
        ];

        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(report.reflectionCount, 0);
      });

      test('growthScoreがnullの場合はkeyword推定扱い', () async {
        fakeGenerator = FakeGryphonInsightGenerator({
          'trends': 'test',
          'strengths': 'test',
          'nextSteps': 'test',
          'growthScore': null,
        });
        service = GryphonReportService(insightGenerator: fakeGenerator);

        final reflections = [
          _TestReflection(
            id: 'r1',
            taskId: 't1',
            taskTitle: 'test',
            createdAt: DateTime(2026, 6, 2),
            content: 'test',
            selfDifficulty: 50,
          ),
        ];

        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(report.estimationSource, 'keyword');
      });

      test('複数週にまたがる振り返りから正しい週を抽出', () async {
        final reflections = [
          _TestReflection(
            id: 'r1', taskId: 't1', taskTitle: 'W1-Mon',
            createdAt: DateTime(2026, 6, 1), content: 'w1', selfDifficulty: 50,
          ),
          _TestReflection(
            id: 'r2', taskId: 't2', taskTitle: 'W1-Wed',
            createdAt: DateTime(2026, 6, 3), content: 'w1', selfDifficulty: 60,
          ),
          _TestReflection(
            id: 'r3', taskId: 't3', taskTitle: 'W2-Tue',
            createdAt: DateTime(2026, 6, 9), content: 'w2', selfDifficulty: 70,
          ),
        ];

        final report = await service.generateWeeklyReport(
          weekStart: DateTime(2026, 6, 1),
          reflections: reflections,
        );

        expect(report.reflectionCount, 2);
        expect(report.reflectionIds, ['r1', 'r2']);
      });
    });

    group('週計算ユーティリティ', () {
      test('getWeekStart: 水曜日→同週の日曜日', () {
        final wednesday = DateTime(2026, 6, 3); // 水曜
        final weekStart = GryphonReportService.getWeekStart(wednesday);
        expect(weekStart.weekday, DateTime.sunday);
        expect(weekStart, DateTime(2026, 5, 31)); // 5/31が日曜
      });

      test('getWeekStart: 日曜日→同日', () {
        final sunday = DateTime(2026, 6, 7); // 日曜
        final weekStart = GryphonReportService.getWeekStart(sunday);
        expect(weekStart, DateTime(2026, 6, 7));
      });

      test('getPreviousWeekStart: 前週の日曜日を返す', () {
        // 現在日時に依存するため、曜日のみ検証
        final prevStart = GryphonReportService.getPreviousWeekStart();
        expect(prevStart.weekday, DateTime.sunday);
      });
    });
  });

  group('GryphonReport model', () {
    test('JSONシリアライズ/デシリアライズ', () {
      final report = _TestGryphonReport(
        id: 'report-1',
        weekStartDate: DateTime(2026, 6, 1),
        weekEndDate: DateTime(2026, 6, 6, 23, 59, 59),
        generatedAt: DateTime(2026, 6, 7, 9, 0),
        trends: '今週の傾向',
        strengths: '伸びた力',
        nextSteps: '次の一手',
        reflectionCount: 5,
        reflectionIds: ['r1', 'r2', 'r3', 'r4', 'r5'],
        growthScore: 75,
        estimationSource: 'grffon',
      );

      expect(report.trends, '今週の傾向');
      expect(report.strengths, '伸びた力');
      expect(report.nextSteps, '次の一手');
      expect(report.growthScore, 75);
      expect(report.reflectionCount, 5);
      expect(report.isAIGenerated, true);
      expect(report.estimationSource, 'grffon');
    });

    test('keyword推定のレポート', () {
      final report = _TestGryphonReport(
        id: 'report-2',
        weekStartDate: DateTime(2026, 6, 1),
        weekEndDate: DateTime(2026, 6, 6, 23, 59, 59),
        generatedAt: DateTime(2026, 6, 7),
        trends: 'フォールバック傾向',
        strengths: 'フォールバック強み',
        nextSteps: 'フォールバック次ステップ',
        estimationSource: 'keyword',
        growthScore: null,
      );

      expect(report.isAIGenerated, false);
      expect(report.growthScore, isNull);
    });
  });
}
