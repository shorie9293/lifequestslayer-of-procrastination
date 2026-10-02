// 週次グリフォン報告リポジトリの試練。
// Hive box "gryphon_reports" への保存・復元・週フィルタを検証する。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/gryphon_report.dart';
import 'package:rpg_todo/features/town/data/gryphon_report_repository.dart';

GryphonReport _report({
  required String id,
  required DateTime weekStart,
  required String trends,
}) {
  return GryphonReport(
    id: id,
    weekStartDate: weekStart,
    weekEndDate: weekStart.add(const Duration(days: 6)),
    generatedAt: weekStart.add(const Duration(days: 1)),
    trends: trends,
    strengths: '伸びた力',
    nextSteps: '次の一手',
    reflectionCount: 3,
    reflectionIds: const ['r1', 'r2', 'r3'],
    growthScore: 72,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_gryphon_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(GryphonReportRepository.boxName);
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('save→getLatest で保存したレポートが復元される', () async {
    final repo = GryphonReportRepository();
    final report = _report(
      id: 'rep-1',
      weekStart: DateTime(2026, 9, 27), // 日曜日
      trends: '継続的な内省の習慣が育っています',
    );

    await repo.save(report);
    final latest = await repo.getLatest();

    expect(latest, isNotNull);
    expect(latest!.id, 'rep-1');
    expect(latest.trends, '継続的な内省の習慣が育っています');
    expect(latest.growthScore, 72);
    expect(latest.reflectionCount, 3);
    expect(latest.weekStartDate, DateTime(2026, 9, 27));
  });

  test('複数保存時は generatedAt が最も新しいレポートを返す', () async {
    final repo = GryphonReportRepository();
    final older = _report(
      id: 'old',
      weekStart: DateTime(2026, 9, 20),
      trends: '古い週',
    );
    final newer = _report(
      id: 'new',
      weekStart: DateTime(2026, 9, 27),
      trends: '新しい週',
    );

    await repo.save(older);
    await repo.save(newer);

    final latest = await repo.getLatest();
    expect(latest!.id, 'new');
  });

  test('getByWeekStart が対象週のレポートのみ返す', () async {
    final repo = GryphonReportRepository();
    await repo.save(_report(
      id: 'w1',
      weekStart: DateTime(2026, 9, 20),
      trends: '先週',
    ));
    await repo.save(_report(
      id: 'w2',
      weekStart: DateTime(2026, 9, 27),
      trends: '今週',
    ));

    final thisWeek = await repo.getByWeekStart(DateTime(2026, 9, 27));
    expect(thisWeek, hasLength(1));
    expect(thisWeek.first.id, 'w2');

    final empty = await repo.getByWeekStart(DateTime(2026, 9, 13));
    expect(empty, isEmpty);
  });

  test('空のボックスでは getLatest が null を返す', () async {
    final repo = GryphonReportRepository();
    expect(await repo.getLatest(), isNull);
  });
}