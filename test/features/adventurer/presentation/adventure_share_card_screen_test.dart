import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/data/adventure_share_card_exporter.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card_service.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_capture.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_screen.dart';

class _FakeCapture implements AdventureShareCardCapture {
  final Uint8List? bytes;
  _FakeCapture(this.bytes);

  @override
  Future<Uint8List?> capture() async => bytes;
}

class _RecordingExporter implements AdventureShareCardExporter {
  final List<({Uint8List png, String text})> calls = [];

  @override
  Future<void> shareImage({required Uint8List png, required String text}) async {
    calls.add((png: png, text: text));
  }
}

AdventureShareCard _card({
  int totalTasks = 42,
  int s = 5,
  int warden = 7,
  int streak = 4,
  int longest = 12,
  int reflections = 20,
}) {
  return AdventureShareCard(
    rankLabel: '熟練冒険者',
    level: 9,
    totalTasksCompleted: totalTasks,
    totalSRankCompleted: s,
    wardenDefeated: warden,
    currentStreak: streak,
    longestStreak: longest,
    totalReflections: reflections,
  );
}

Player _player({int totalTasks = 42}) {
  return Player(
    jobLevels: {Job.adventurer: 3},
    totalTasksCompleted: totalTasks,
  );
}

void main() {
  testWidgets('画面が描画され Preview/Share/Copy キーが存在する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AdventureShareCardScreen(card: _card())),
    );
    expect(find.byKey(AppKeys.adventureShareCardPreview), findsOneWidget);
    expect(find.byKey(AppKeys.adventureShareCardShare), findsOneWidget);
    expect(find.byKey(AppKeys.adventureShareCardCopy), findsOneWidget);
    expect(find.byKey(AppKeys.adventureShareCardView), findsOneWidget);
    expect(find.text('戦績カードを共有'), findsOneWidget);
  });

  testWidgets('共有ボタンで capture→exporter が呼ばれ SnackBar が出る', (tester) async {
    final exporter = _RecordingExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureShareCardScreen(
          card: _card(),
          capture: _FakeCapture(Uint8List.fromList([1, 2, 3])),
          exporter: exporter,
        ),
      ),
    );
    await tester.tap(find.byKey(AppKeys.adventureShareCardShare));
    await tester.pump();
    expect(exporter.calls, hasLength(1));
    expect(
      exporter.calls.single.text,
      AdventureShareCardService.shareText(_card()),
    );
    expect(exporter.calls.single.png, isNotEmpty);
    expect(find.text('カードを共有しました'), findsOneWidget);
  });

  testWidgets('capture が null を返したら exporter は呼ばれず SnackBar が出る', (tester) async {
    final exporter = _RecordingExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureShareCardScreen(
          card: _card(),
          capture: _FakeCapture(null),
          exporter: exporter,
        ),
      ),
    );
    await tester.tap(find.byKey(AppKeys.adventureShareCardShare));
    await tester.pump();
    expect(exporter.calls, isEmpty);
    expect(find.text('カード画像を生成できませんでした'), findsOneWidget);
  });

  testWidgets('exporter が例外を投げたら失敗 SnackBar が出る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureShareCardScreen(
          card: _card(),
          capture: _FakeCapture(Uint8List.fromList([1])),
          exporter: _ThrowingExporter(),
        ),
      ),
    );
    await tester.tap(find.byKey(AppKeys.adventureShareCardShare));
    await tester.pump();
    expect(find.text('カードの共有に失敗しました'), findsOneWidget);
  });

  testWidgets('コピーボタンで SnackBar テキストをコピーしました が出る', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AdventureShareCardScreen(card: _card())),
    );
    await tester.tap(find.byKey(AppKeys.adventureShareCardCopy));
    await tester.pump();
    expect(find.text('テキストをコピーしました'), findsOneWidget);
  });

  testWidgets('0値の戦績カードでもクラッシュしない', (tester) async {
    const card = AdventureShareCard(
      rankLabel: '駆け出し',
      level: 1,
      totalTasksCompleted: 0,
      totalSRankCompleted: 0,
      wardenDefeated: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalReflections: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureShareCardScreen(
          card: card,
          capture: _FakeCapture(Uint8List.fromList([1])),
          exporter: _RecordingExporter(),
        ),
      ),
    );
    await tester.tap(find.byKey(AppKeys.adventureShareCardShare));
    await tester.pump();
    expect(find.byType(AdventureShareCardScreen), findsOneWidget);
    expect(find.text('カードを共有しました'), findsOneWidget);
  });

  test('ShareCardScreen に注入した capture 実装が null context で null を返す', () async {
    final capture = RepaintBoundaryAdventureShareCardCapture(LabeledGlobalKey('t'));
    expect(await capture.capture(), isNull);
  });

  test('AdventureShareCardService.build が Player から組める（配線用の健全性確認）', () {
    final card = AdventureShareCardService.build(_player(totalTasks: 42));
    expect(card.totalTasksCompleted, 42);
  });
}

class _ThrowingExporter implements AdventureShareCardExporter {
  @override
  Future<void> shareImage({required Uint8List png, required String text}) async {
    throw Exception('boom');
  }
}
