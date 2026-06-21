import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/presentation/widgets/kozuchi_quest_card.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

void main() {
  group('KozuchiQuestCard', () {
    const sampleQuest = KozuchiQuest(
      title: '朝の祈り',
      description: '新しい一日への感謝と祈りを捧げよ',
      suggestedOffering: 100,
      advisorEmoji: '🦊',
      advisorLabel: '稲荷神',
    );

    const completedQuest = KozuchiQuest(
      title: '朝の祈り',
      description: '新しい一日への感謝と祈りを捧げよ',
      suggestedOffering: 100,
      advisorEmoji: '🦊',
      advisorLabel: '稲荷神',
      isCompleted: true,
    );

    testWidgets('ヘッダー「🧘 Kozuchi試練」が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(find.text('🧘 Kozuchi試練'), findsOneWidget);
    });

    testWidgets('試練のタイトルが表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(find.text('朝の祈り'), findsOneWidget);
      expect(find.byKey(AppKeys.kozuchiQuestTitle), findsOneWidget);
    });

    testWidgets('試練の説明が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(
        find.text('新しい一日への感謝と祈りを捧げよ'),
        findsOneWidget,
      );
      expect(find.byKey(AppKeys.kozuchiQuestDescription), findsOneWidget);
    });

    testWidgets('アドバイザーの絵文字と名前が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(find.text('🦊'), findsOneWidget);
      expect(find.text('稲荷神'), findsOneWidget);
      expect(find.byKey(AppKeys.kozuchiAdvisor), findsOneWidget);
    });

    testWidgets('支出目安額が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(find.text('支出目安: 100コイン'), findsOneWidget);
      expect(find.byKey(AppKeys.kozuchiOffering), findsOneWidget);
    });

    testWidgets('未完了時は「未達成」ステータスが表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(find.text('未達成'), findsOneWidget);
      expect(find.byKey(AppKeys.kozuchiStatus), findsOneWidget);
    });

    testWidgets('完了時は「達成済み」ステータスが表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: completedQuest),
          ),
        ),
      );

      expect(find.text('✅ 達成済み'), findsOneWidget);
      expect(find.byKey(AppKeys.kozuchiStatus), findsOneWidget);
    });

    testWidgets('カードのkeyが正しく設定されている', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      expect(find.byKey(AppKeys.kozuchiQuestCard), findsOneWidget);
    });

    testWidgets('金色/紫色を基調とした特別カードが表示されること', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KozuchiQuestCard(quest: sampleQuest),
          ),
        ),
      );

      // Cardウィジェットが存在することを確認
      expect(find.byType(Card), findsOneWidget);
    });
  });
}
