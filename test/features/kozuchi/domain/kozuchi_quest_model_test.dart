import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';

void main() {
  group('KozuchiQuest.fromJson', () {
    test('完全なJSONから正しくパースされる', () {
      final json = <String, dynamic>{
        'title': 'コンビニ誘惑を断て',
        'description': '3日間コンビニで無駄遣いせず、必要なものだけ買う',
        'suggestedOffering': 500,
        'advisor': 'investmentMentor',
        'isCompleted': false,
      };

      final quest = KozuchiQuest.fromJson(json);

      expect(quest.title, 'コンビニ誘惑を断て');
      expect(quest.description, '3日間コンビニで無駄遣いせず、必要なものだけ買う');
      expect(quest.suggestedOffering, 500);
      expect(quest.advisorEmoji, '⚔️');
      expect(quest.advisorLabel, '投資メンター');
      expect(quest.isCompleted, false);
    });

    test('completed な試練から正しくパースされる', () {
      final json = <String, dynamic>{
        'title': '感謝の手紙を書く',
        'description': '家族に感謝の手紙を書いて渡す',
        'suggestedOffering': 300,
        'advisor': 'wellnessAdvisor',
        'isCompleted': true,
      };

      final quest = KozuchiQuest.fromJson(json);

      expect(quest.title, '感謝の手紙を書く');
      expect(quest.advisorEmoji, '🌸');
      expect(quest.advisorLabel, 'ウェルネスアドバイザー');
      expect(quest.isCompleted, true);
    });

    test('lifePlanner のアドバイザーが正しくマッピングされる', () {
      final json = <String, dynamic>{
        'title': '食品ロスを減らせ',
        'description': '1週間、食材を無駄にしない',
        'suggestedOffering': 1000,
        'advisor': 'lifePlanner',
        'isCompleted': false,
      };

      final quest = KozuchiQuest.fromJson(json);

      expect(quest.advisorEmoji, '🪘');
      expect(quest.advisorLabel, 'ライフプランナー');
    });

    test('careerCoach のアドバイザーが正しくマッピングされる', () {
      final json = <String, dynamic>{
        'title': '新しい曲を覚える',
        'description': '今週中に新しい楽器の曲を1曲練習する',
        'suggestedOffering': 200,
        'advisor': 'careerCoach',
        'isCompleted': false,
      };

      final quest = KozuchiQuest.fromJson(json);

      expect(quest.advisorEmoji, '🎵');
      expect(quest.advisorLabel, 'キャリアコーチ');
    });

    test('必須フィールドが欠落していると ArgumentError を投げる（title 欠落）', () {
      final json = <String, dynamic>{
        'description': '説明だけ',
        'suggestedOffering': 100,
        'advisor': 'lifePlanner',
        'isCompleted': false,
      };

      expect(
        () => KozuchiQuest.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('必須フィールドが欠落していると ArgumentError を投げる（advisor 欠落）', () {
      final json = <String, dynamic>{
        'title': 'タイトル',
        'description': '説明',
        'suggestedOffering': 100,
        'isCompleted': false,
      };

      expect(
        () => KozuchiQuest.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('無効な advisor 文字列はデフォルト値で代替される', () {
      final json = <String, dynamic>{
        'title': 'テスト',
        'description': '説明',
        'suggestedOffering': 100,
        'advisor': 'unknown_god',
        'isCompleted': false,
      };

      // デフォルトの絵文字とラベルになること
      final quest = KozuchiQuest.fromJson(json);

      expect(quest.advisorEmoji, isNotEmpty);
      expect(quest.advisorLabel, isNotEmpty);
    });

    test('suggestedOffering が null の場合でもエラーにならない', () {
      final json = <String, dynamic>{
        'title': 'テスト',
        'description': '説明',
        'suggestedOffering': null,
        'advisor': 'lifePlanner',
        'isCompleted': false,
      };

      final quest = KozuchiQuest.fromJson(json);

      expect(quest.suggestedOffering, 0);
    });

    test('isCompleted が null の場合のデフォルトは false', () {
      final json = <String, dynamic>{
        'title': 'テスト',
        'description': '説明',
        'suggestedOffering': 100,
        'advisor': 'lifePlanner',
      };

      final quest = KozuchiQuest.fromJson(json);

      expect(quest.isCompleted, false);
    });
  });
}
