// 振り返りの杜画面の件数看板と実描画の一致を検証する試練。
// 見出しは全件数を掲げるため、タイル列も全件を（遅延描画で）辿れることを確かめる。
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

/// 実Hiveを触らないメモリ実装（画面内の報告読込を FakeAsync で完了させる）。
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

Reflection _reflection(int index, DateTime date) {
  return Reflection(
    id: 'r$index',
    taskId: 'task-$index',
    date: date,
    content: '振り返り本文$index',
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
    tempDir = Directory.systemTemp.createTempSync('hive_grove_paging_');
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

  /// 与えた件数の振り返りを保存する（index 0 が最新）。
  Future<void> seed(WidgetTester tester, int count) async {
    final repo = ReflectionRepository();
    final base = DateTime(2026, 1, 1, 12);
    await tester.runAsync(() async {
      for (int i = 0; i < count; i++) {
        await repo.save(
          _reflection(i, base.subtract(Duration(minutes: i))),
        );
      }
    });
  }

  Future<void> pumpGrove(WidgetTester tester) async {
    // 実 Hive の openBox は FakeAsync ゾーンで完了しないため runAsync で開口する
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
    // _load() の Hive box 読込 → setState を実時間で完了させる
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('25件保存時、看板は25件でタイルも25件すべて描画される', (tester) async {
    // 遅延描画のため、全件を一度に build させるには縦長のviewportが必要。
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seed(tester, 25);
    await pumpGrove(tester);

    expect(find.textContaining('学びの記録（25件）'), findsOneWidget);
    expect(_tileFinder, findsNWidgets(25));
  });

  testWidgets('20件ちょうどでは従来通り全件描画される', (tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seed(tester, 20);
    await pumpGrove(tester);

    expect(find.textContaining('学びの記録（20件）'), findsOneWidget);
    expect(_tileFinder, findsNWidgets(20));
  });

  testWidgets('0件では空状態文言が表示される', (tester) async {
    await pumpGrove(tester);

    expect(find.text('まだ振り返りがありません。'), findsOneWidget);
    expect(_tileFinder, findsNothing);
  });

  testWidgets('21件目以降もスクロールで到達できる（take(20) の穴が閉じている）', (tester) async {
    // 既定の viewport（800x600）のまま、遅延描画のままスクロールで辿る。
    await seed(tester, 25);
    await pumpGrove(tester);

    // 21件目（0始まり index 20）以降はスクロールしないと build されない。
    expect(find.text('振り返り本文20'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('振り返り本文24'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('振り返り本文24'), findsOneWidget);
  });
}
