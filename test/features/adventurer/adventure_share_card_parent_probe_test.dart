// 親探針: 冒険の戦績シェアカード（#125）の合成不変条件
// 画面→service→表示 の合成、および 0 戦績の境界を撃つ。
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/data/adventure_share_card_exporter.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card_service.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_capture.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_screen.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_view.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventurer_chart_screen.dart';

Player _player({
  int totalTasks = 0,
  int s = 0,
  int warden = 0,
  int streak = 0,
  int longest = 0,
  int reflections = 0,
  int level = 3,
}) {
  return Player(
    jobLevels: {Job.adventurer: level},
    totalTasksCompleted: totalTasks,
    totalSRankCompleted: s,
    timesWardenDefeated: warden,
    streakDays: streak,
    longestStreak: longest,
    totalReflections: reflections,
  );
}

class _FakeCapture implements AdventureShareCardCapture {
  final Uint8List? result;
  _FakeCapture(this.result);
  @override
  Future<Uint8List?> capture() async => result;
}

class _FakeExporter implements AdventureShareCardExporter {
  Uint8List? png;
  String? text;
  @override
  Future<void> shareImage({
    required Uint8List png,
    required String text,
  }) async {
    this.png = png;
    this.text = text;
  }
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('探針1: Player→build→画面 の合成で各戦績値が描画される', (tester) async {
    final card = AdventureShareCardService.build(_player(
      totalTasks: 42,
      s: 5,
      warden: 7,
      longest: 12,
      reflections: 20,
      level: 9,
    ));
    await tester.pumpWidget(_wrap(AdventureShareCardView(card: card)));
    expect(find.text('熟練冒険者'), findsOneWidget);
    expect(find.text('Lv.9'), findsOneWidget);
    expect(find.text('総クエスト完了'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Sランク'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('刻の番人討伐'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('最長ストリーク'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    // 現在ストリーク(0)は行に出ない
    expect(find.text('現在のストリーク'), findsNothing);
  });

  testWidgets('探針2: 共有ボタン→exporter に Player 実値を含むテキストが渡る（end-to-end）',
      (tester) async {
    final player = _player(totalTasks: 42, s: 5, warden: 7, longest: 12, reflections: 20);
    final card = AdventureShareCardService.build(player);
    final exporter = _FakeExporter();
    await tester.pumpWidget(_wrap(AdventureShareCardScreen(
      card: card,
      capture: _FakeCapture(Uint8List.fromList([1, 2, 3])),
      exporter: exporter,
    )));
    await tester.tap(find.byKey(AppKeys.adventureShareCardShare));
    await tester.pumpAndSettle();
    expect(exporter.png, isNotNull);
    expect(exporter.text, isNotNull);
    expect(exporter.text, AdventureShareCardService.shareText(card));
    expect(exporter.text, contains('総クエスト完了: 42件'));
    expect(exporter.text, contains('Sランク: 5件'));
  });

  testWidgets('探針3: 0戦績は空メッセージ・hasProgress false・数値行なし', (tester) async {
    final card = AdventureShareCardService.build(_player());
    expect(card.hasProgress, isFalse);
    await tester.pumpWidget(_wrap(AdventureShareCardView(card: card)));
    expect(find.text('これからの冒険にご期待あれ！'), findsOneWidget);
    expect(find.text('総クエスト完了'), findsNothing);
    final text = AdventureShareCardService.shareText(card);
    expect(text.contains('件'), isFalse);
    expect(text.contains('#RPGタスク'), isTrue);
  });

  testWidgets('探針4: 冒険者カルテの導線から遷移し、注入Playerの実値がカードに現れる', (tester) async {
    final player = _player(totalTasks: 42, s: 5, warden: 7, level: 9);
    await tester.pumpWidget(_wrap(AdventurerChartScreen(player: player)));
    await tester.tap(find.byKey(AppKeys.adventureChartShareEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.adventureShareCardScreen), findsOneWidget);
    expect(find.text('Lv.9'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });
}
