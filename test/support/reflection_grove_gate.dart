// 振り返りの杜のライト実描画コントラスト走査（Hive 実リポジトリ前提）。
//
// この画面は Hive Box を自前で開くため、汎用ランナ（contrast_runner）の
// needsHive では Box のライフサイクルが噛み合わない。ここでは setUp/tearDown で
// Hive を明示的に初期化・破棄し、Box を pre-open してから pump する。
// 判定は contrast_gate の scanContrast / expectLightContrast を再利用し、
// コントラスト算出・母数判定のロジックを一切複製しない。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/gryphon_report.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/town/data/gryphon_report_repository.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';

import 'contrast_gate.dart';
import 'test_viewport.dart';

/// 振り返りの杜の走査方言：RenderDecoratedBox の色のみ（Material/ColoredBox/Chip を見ない）。
const ScanConfig _groveConfig = ScanConfig(
  measurablePattern: kExtendedMeasurablePattern,
  gradientMode: GradientMode.none,
  includeRawChip: false,
  includeColoredBox: false,
  includeMaterial: false,
);

class _InMemoryGryphonReportRepository extends GryphonReportRepository {
  final List<GryphonReport> _reports = [];
  @override
  Future<void> save(GryphonReport report) async => _reports.add(report);
  @override
  Future<List<GryphonReport>> getAll() async =>
      [..._reports]..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  @override
  Future<void> clearAll() async => _reports.clear();
}

/// 振り返りの杜のライト走査 2 ケースを登録する。
void runReflectionGroveGate() {
  late Directory tempDir;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(ReflectionAdapter().typeId)) {
      Hive.registerAdapter(ReflectionAdapter());
    }
    if (!Hive.isAdapterRegistered(QuestionRankAdapter().typeId)) {
      Hive.registerAdapter(QuestionRankAdapter());
    }
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('rg_gate_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seed(WidgetTester tester, int count) async {
    final repo = ReflectionRepository();
    final base = DateTime(2026, 1, 1, 12);
    await tester.runAsync(() async {
      for (var i = 0; i < count; i++) {
        await repo.save(Reflection(
          id: 'r$i',
          taskId: 'task-$i',
          date: base.subtract(Duration(minutes: i)),
          content: '振り返り本文$i',
          selfDifficulty: 1 + (i % 5),
          aiDifficulty: QuestRank.values[i % QuestRank.values.length],
        ));
      }
    });
  }

  Future<void> pumpGrove(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: GameThemes.lightForJob(Job.adventurer),
        home: ReflectionGroveScreen(
          onBack: () {},
          reportRepository: _InMemoryGryphonReportRepository(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('振り返りの杜（空状態）: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    useRealDeviceViewport(tester, widthDp: 430);
    await pumpGrove(tester);
    final scan = scanContrast(tester, config: _groveConfig);
    expectLightContrast(scan, minMeasurable: 2, label: 'REFLECTION GROVE empty');
  });

  testWidgets('振り返りの杜: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    useRealDeviceViewport(tester, widthDp: 430);
    await seed(tester, 12);
    await pumpGrove(tester);
    final scan = scanContrast(tester, config: _groveConfig);
    expectLightContrast(scan, minMeasurable: 10, label: 'REFLECTION GROVE full');
  });
}