import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/domain/difficulty_estimator.dart';
import 'package:rpg_todo/domain/models/task.dart';

void main() {
  group('DifficultyEstimator', () {
    group('Sランク判定', () {
      test('「本番デプロイ」でS', () {
        expect(DifficultyEstimator.estimateRank('本番デプロイ'), QuestRank.S);
      });

      test('「緊急のバグ修正」でS', () {
        expect(DifficultyEstimator.estimateRank('緊急のバグ修正'), QuestRank.S);
      });

      test('「リリース前の最終確認」でS', () {
        expect(DifficultyEstimator.estimateRank('リリース前の最終確認'),
            QuestRank.S);
      });

      test('「障害対応：サーバーダウン」でS', () {
        expect(DifficultyEstimator.estimateRank('障害対応：サーバーダウン'),
            QuestRank.S);
      });

      test('「締切厳守の重要案件」でS', () {
        expect(DifficultyEstimator.estimateRank('締切厳守の重要案件'),
            QuestRank.S);
      });

      test('「インシデント報告」でS', () {
        expect(DifficultyEstimator.estimateRank('インシデント報告'), QuestRank.S);
      });

      test('「火消し」でS', () {
        expect(DifficultyEstimator.estimateRank('火消し'), QuestRank.S);
      });
    });

    group('Aランク判定', () {
      test('「新機能の実装」でA', () {
        expect(DifficultyEstimator.estimateRank('新機能の実装'), QuestRank.A);
      });

      test('「設計ドキュメントの作成」でA', () {
        expect(DifficultyEstimator.estimateRank('設計ドキュメントの作成'),
            QuestRank.A);
      });

      test('「コードレビュー」でA', () {
        expect(DifficultyEstimator.estimateRank('コードレビュー'), QuestRank.A);
      });

      test('「分析レポートの作成」でA', () {
        expect(DifficultyEstimator.estimateRank('分析レポートの作成'),
            QuestRank.A);
      });

      test('「データ移行計画」でA', () {
        expect(DifficultyEstimator.estimateRank('データ移行計画'), QuestRank.A);
      });

      test('「システムの最適化」でA', () {
        expect(DifficultyEstimator.estimateRank('システムの最適化'), QuestRank.A);
      });

      test('「リファクタリング」でA', () {
        expect(DifficultyEstimator.estimateRank('リファクタリング'), QuestRank.A);
      });

      test('16文字の長いタイトルは自動的にAランク', () {
        expect(DifficultyEstimator.estimateRank('あいうえおかきくけこさしすせそた'),
            QuestRank.A);
      });

      test('「テストケースの作成」でA', () {
        expect(DifficultyEstimator.estimateRank('テストケースの作成'),
            QuestRank.A);
      });
    });

    group('Bランク判定', () {
      test('「買い物」でB', () {
        expect(DifficultyEstimator.estimateRank('買い物'), QuestRank.B);
      });

      test('「メール返信」でB', () {
        expect(DifficultyEstimator.estimateRank('メール返信'), QuestRank.B);
      });

      test('短い日常タスクはB', () {
        expect(DifficultyEstimator.estimateRank('ゴミ出し'), QuestRank.B);
      });

      test('「散歩」でB', () {
        expect(DifficultyEstimator.estimateRank('散歩'), QuestRank.B);
      });

      test('「読書」でB', () {
        expect(DifficultyEstimator.estimateRank('読書'), QuestRank.B);
      });
    });

    group('優先順位', () {
      test('Sキーワードがあれば文字数に関係なくS', () {
        // 「緊急」が含まれているため、15文字以下でもS
        expect(DifficultyEstimator.estimateRank('緊急'), QuestRank.S);
      });

      test('Aキーワードがなくても16文字以上ならA', () {
        expect(
          DifficultyEstimator.estimateRank('あいうえおかきくけこさしすせそた'),
          QuestRank.A,
        );
      });

      test('Aキーワードあり+短文でもA', () {
        expect(DifficultyEstimator.estimateRank('実装'), QuestRank.A);
      });
    });

    group('エッジケース', () {
      test('空文字列はB', () {
        expect(DifficultyEstimator.estimateRank(''), QuestRank.B);
      });

      test('1文字はB', () {
        expect(DifficultyEstimator.estimateRank('a'), QuestRank.B);
      });

      test('全角スペースだけでもB', () {
        expect(DifficultyEstimator.estimateRank('　'), QuestRank.B);
      });

      test('S/Aキーワードを含まない長い文字列はA', () {
        final longTitle = List.filled(20, 'あ').join();
        expect(DifficultyEstimator.estimateRank(longTitle), QuestRank.A);
      });

      test('英語タイトルで16文字超ならA', () {
        expect(
          DifficultyEstimator.estimateRank(
              'This is a long task title'),
          QuestRank.A,
        );
      });

      test('英語タイトルで短ければB', () {
        expect(DifficultyEstimator.estimateRank('Read book'), QuestRank.B);
      });
    });
  });
}
