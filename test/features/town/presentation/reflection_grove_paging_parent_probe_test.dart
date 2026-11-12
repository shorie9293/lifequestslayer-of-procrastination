// 親探針（イシコリドメ）— #240 の受入基準を親が独立に撃つ。
// 子の試練は「25件が描画される」ことを確かめるが、
// 「take(20) を消して Column へ全件展開しただけ」でも 25件は緑になる。
// よってここでは **大量件数で遅延描画になっていること** と
// **最古の1件まで実際に到達できること** を不変条件として固定する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/gryphon_report.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/town/data/gryphon_report_repository.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';

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

Reflection _reflection(int index, DateTime date) {
  return Reflection(
    id: 'p$index',
    taskId: 'task-$index',
    date: date,
    content: '親探針本文$index',
    selfDifficulty: 3,
    aiDifficulty: QuestRank.A,
  );
}

/// _ReflectionTile は private のため runtimeType 名で同定する。
final Finder _tileFinder = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_ReflectionTile',
);

void main() {
  late Directory tempDir;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_grove_probe_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> seed(WidgetTester tester, int count) async {
    final repo = ReflectionRepository();
    final base = DateTime(2026, 1, 1, 12);
    await tester.runAsync(() async {
      for (int i = 0; i < count; i++) {
        await repo.save(_reflection(i, base.subtract(Duration(minutes: i))));
      }
    });
  }

  Future<void> pumpGrove(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Hive.openBox<Reflection>(ReflectionRepository.boxName);
    });
    await tester.pumpWidget(
      MaterialApp(
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

  testWidgets('探針1: 300件でも初回buildは全件でない（遅延描画の実証）', (tester) async {
    await seed(tester, 300);
    await pumpGrove(tester);

    // 看板は全件を掲げる。
    expect(find.textContaining('学びの記録（300件）'), findsOneWidget);

    // 実描画は画面に収まる分だけ＝Column全件展開（300）ではない。
    // （ヘッダ群が高いため初回はタイル0件でも正常＝遅延描画の証左）
    final built = tester.widgetList(_tileFinder).length;
    expect(
      built,
      lessThan(100),
      reason: 'SliverList の遅延描画なら初回buildは可視分のみ。'
          'take(20)除去＋Column展開だと 300 になる＝遅延描画の回帰。',
    );
  });

  testWidgets('探針2: 300件の最古（301件目相当）まで実際にスクロールで到達できる',
      (tester) async {
    await seed(tester, 300);
    await pumpGrove(tester);

    await tester.scrollUntilVisible(
      find.text('親探針本文299'),
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 400,
    );
    await tester.pump();

    expect(find.text('親探針本文299'), findsOneWidget);
  });

  testWidgets('探針3: 21件のとき看板と到達可能件数が一致する（境界）', (tester) async {
    await seed(tester, 21);
    await pumpGrove(tester);

    expect(find.textContaining('学びの記録（21件）'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('親探針本文20'),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.pump();

    expect(find.text('親探針本文20'), findsOneWidget);
  });
}