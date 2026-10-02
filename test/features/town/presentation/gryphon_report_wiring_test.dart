// 週次グリフォン報告の画面配線試練。
// 振り返りの杜画面からグリフォン報告を生成・表示・永続化できることを検証する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/gryphon_report.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/gryphon_insight_generator.dart';
import 'package:rpg_todo/features/town/data/gryphon_report_repository.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';

/// 固定インサイトを返す Fake ジェネレータ（AI 呼び出しを回避）。
class _FakeInsightGenerator implements GryphonInsightGenerator {
  @override
  Future<Map<String, dynamic>> generateInsight(
    List<String> reflectionContents,
    List<String> taskTitles,
    List<int> selfDifficulties,
  ) async {
    return {
      'trends': '今週は挑戦的なクエストに継続的に取り組んだ傾向が見られる',
      'strengths': '困難なクエストへの挑戦心が伸びている',
      'nextSteps': '- 振り返りの記述をより具体的に',
      'growthScore': 68,
    };
  }
}

/// 実Hiveを触らないメモリ実装（画面内の save が FakeAsync で完了するように）。
class _InMemoryGryphonReportRepository extends GryphonReportRepository {
  final List<GryphonReport> _reports = [];

  @override
  Future<void> save(GryphonReport report) async {
    _reports.add(report);
  }

  @override
  Future<List<GryphonReport>> getAll() async =>
      [..._reports]..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

  @override
  Future<void> clearAll() async => _reports.clear();
}

Reflection _reflection(String id, DateTime date) {
  return Reflection(
    id: id,
    taskId: 'task-$id',
    date: date,
    content: '難しかったが次は改善する',
    selfDifficulty: 3,
    aiDifficulty: QuestRank.A,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_gryphon_ui_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    // deleteBoxFromDisk は実IOのため FakeAsync ゾーンで完了しない。
    // テストごとに専用 tempDir を使うため、クローズのみで十分。
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpGrove(
    WidgetTester tester, {
    required GryphonReportRepository reportRepo,
  }) async {
    // 実 Hive の openBox は FakeAsync ゾーンで完了しないため runAsync で開口する
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ReflectionGroveScreen(
          onBack: () {},
          insightGenerator: _FakeInsightGenerator(),
          reportRepository: reportRepo,
        ),
      ),
    );
    // _load() の Hive box 読込 → setState を実時間で完了させる
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('生成ボタン押下で週次グリフォン報告カードが表示される',
      (tester) async {
    final reflectionRepo = ReflectionRepository();
    await tester.runAsync(() async {
      await reflectionRepo.save(_reflection('r1', DateTime.now()));
    });
    final reportRepo = _InMemoryGryphonReportRepository();

    await pumpGrove(tester, reportRepo: reportRepo);

    // 生成ボタンを押す
    await tester.tap(find.byKey(AppKeys.gryphonReportGenerateButton));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // カードが表示され、Fake のインサイト内容が描画される
    expect(find.byKey(AppKeys.gryphonReportCard), findsOneWidget);
    expect(find.textContaining('今週は挑戦的なクエスト'), findsOneWidget);
    expect(find.textContaining('困難なクエストへの挑戦心'), findsOneWidget);
    expect(find.byKey(AppKeys.gryphonReportGrowthScore), findsOneWidget);
    expect(find.textContaining('68'), findsOneWidget);
  });

  testWidgets('生成した報告はリポジトリに永続化される', (tester) async {
    final reflectionRepo = ReflectionRepository();
    await tester.runAsync(() async {
      await reflectionRepo.save(_reflection('r1', DateTime.now()));
    });
    final reportRepo = _InMemoryGryphonReportRepository();

    await pumpGrove(tester, reportRepo: reportRepo);

    await tester.tap(find.byKey(AppKeys.gryphonReportGenerateButton));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final latest = await tester
        .runAsync<GryphonReport?>(() => reportRepo.getLatest());
    expect(latest, isNotNull);
    expect(latest!.trends, contains('今週は挑戦的なクエスト'));
    expect(latest.growthScore, 68);
    expect(latest.reflectionCount, 1);
  });

  testWidgets('起動時に保存済み報告が復元される（生成ボタン押下前にカード表示）',
      (tester) async {
    final reflectionRepo = ReflectionRepository();
    await tester.runAsync(() async {
      await reflectionRepo.save(_reflection('r1', DateTime.now()));
    });
    final reportRepo = _InMemoryGryphonReportRepository();
    final weekStart = DateTime.now();
    await tester.runAsync(() async {
      await reportRepo.save(GryphonReport(
        id: 'stored',
        weekStartDate: weekStart,
        weekEndDate: weekStart.add(const Duration(days: 6)),
        generatedAt: DateTime.now(),
        trends: '保存済みの傾向テキスト',
        strengths: '保存済みの伸びた力',
        nextSteps: '保存済みの次の一手',
        reflectionCount: 2,
        growthScore: 55,
      ));
    });

    await pumpGrove(tester, reportRepo: reportRepo);

    expect(find.byKey(AppKeys.gryphonReportCard), findsOneWidget);
    expect(find.textContaining('保存済みの傾向テキスト'), findsOneWidget);
  });

  testWidgets('報告が未生成の間は空状態が表示される', (tester) async {
    final reflectionRepo = ReflectionRepository();
    await tester.runAsync(() async {
      await reflectionRepo.save(_reflection('r1', DateTime.now()));
    });
    final reportRepo = _InMemoryGryphonReportRepository();

    await pumpGrove(tester, reportRepo: reportRepo);

    expect(find.byKey(AppKeys.gryphonReportEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.gryphonReportCard), findsNothing);
  });
}