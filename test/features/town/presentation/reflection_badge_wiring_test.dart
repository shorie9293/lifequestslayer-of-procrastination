// 内省バッジコレクション画面への導線（振り返りの杜 → バッジ画面）試練。
//
// 振り返りの杜の AppBar に追加した導線ボタンが実在し、タップで
// バッジコレクション画面へ遷移することを実経路で検証する。
// Hive は一時ディレクトリで初期化し、reflections box を事前オープンする。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/town/presentation/reflection_grove_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_badge_wire_run_');
    Hive.init(tempDir.path);
    try {
      await Hive.openBox<Reflection>('reflections');
    } catch (_) {}
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('振り返りの杜に内省バッジ導線ボタンが存在する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReflectionGroveScreen(onBack: () {})),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.byKey(AppKeys.reflectionBadgeCollectionButton), findsOneWidget);
  });

  testWidgets('導線ボタンのタップでバッジコレクション画面へ遷移する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReflectionGroveScreen(onBack: () {})),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.reflectionBadgeCollectionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(AppKeys.reflectionBadgeCollectionScreen),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
