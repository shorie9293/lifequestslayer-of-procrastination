import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/domain/difficulty_estimator.dart';
import 'package:rpg_todo/domain/models/task.dart';

void main() {
  group('DifficultyEstimator.estimateRank', () {
    group('Sランク判定（最重要・緊急）', () {
      test('「本番」を含むタイトルはSランク', () {
        expect(
          DifficultyEstimator.estimateRank('本番環境へのデプロイ'),
          QuestRank.S,
        );
      });

      test('「デプロイ」を含むタイトルはSランク', () {
        expect(
          DifficultyEstimator.estimateRank('アプリのデプロイ作業'),
          QuestRank.S,
        );
      });

      test('「リリース」を含むタイトルはSランク', () {
        expect(
          DifficultyEstimator.estimateRank('v2.0リリース準備'),
          QuestRank.S,
        );
      });

      test('「緊急」を含むタイトルはSランク', () {
        expect(
          DifficultyEstimator.estimateRank('緊急：サーバーダウン対応'),
          QuestRank.S,
        );
      });

      test('「障害」を含むタイトルはSランク', () {
        expect(
          DifficultyEstimator.estimateRank('本番障害の調査'),
          QuestRank.S,
        );
      });

      test('「締切」を含むタイトルはSランク', () {
        expect(
          DifficultyEstimator.estimateRank('提案書の締切が明日'),
          QuestRank.S,
        );
      });
    });

    group('Aランク判定（重要・中規模）', () {
      test('「実装」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('ログイン機能の実装'),
          QuestRank.A,
        );
      });

      test('「開発」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('新機能の開発'),
          QuestRank.A,
        );
      });

      test('「会議」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('週次進捗会議の準備'),
          QuestRank.A,
        );
      });

      test('「資料」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('提案資料の作成'),
          QuestRank.A,
        );
      });

      test('「設計」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('データベース設計'),
          QuestRank.A,
        );
      });

      test('「テスト」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('単体テストの作成'),
          QuestRank.A,
        );
      });

      test('「レビュー」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('コードレビュー対応'),
          QuestRank.A,
        );
      });

      test('「調査」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('パフォーマンス問題の調査'),
          QuestRank.A,
        );
      });

      test('「分析」を含むタイトルはAランク', () {
        expect(
          DifficultyEstimator.estimateRank('ユーザー行動の分析'),
          QuestRank.A,
        );
      });

      test('30文字超のタイトルはAランク（S/Aキーワードなしの場合）', () {
        expect(
          DifficultyEstimator.estimateRank(
            '明日までに提出が必要な週次レポートのまとめとグラフ作成',
          ),
          QuestRank.A,
        );
      });
    });

    group('Bランク判定（通常・軽量）', () {
      test('「作成」を含むタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('スライドの作成'),
          QuestRank.B,
        );
      });

      test('「買い物」を含むタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('週末の買い物リスト'),
          QuestRank.B,
        );
      });

      test('「連絡」を含むタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('取引先への連絡'),
          QuestRank.B,
        );
      });

      test('「確認」を含むタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('メールの確認'),
          QuestRank.B,
        );
      });

      test('「掃除」を含むタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('部屋の掃除'),
          QuestRank.B,
        );
      });

      test('「運動」を含むタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('朝の運動'),
          QuestRank.B,
        );
      });

      test('15文字超のタイトルはBランク（S/A/Bキーワードなしの場合）', () {
        expect(
          DifficultyEstimator.estimateRank('明日の天気を確認する'),
          QuestRank.B,
        );
      });
    });

    group('デフォルト（Bランク）', () {
      test('短くてキーワードのないタイトルはBランク', () {
        expect(
          DifficultyEstimator.estimateRank('ゴミ出し'),
          QuestRank.B,
        );
      });

      test('空文字列はBランク', () {
        expect(
          DifficultyEstimator.estimateRank(''),
          QuestRank.B,
        );
      });

      test('「休憩」はBランク', () {
        expect(
          DifficultyEstimator.estimateRank('休憩'),
          QuestRank.B,
        );
      });
    });

    group('優先順位', () {
      test('SキーワードがAより優先される', () {
        expect(
          DifficultyEstimator.estimateRank('本番リリースの実装とテスト'),
          QuestRank.S,
        );
      });

      test('AキーワードがBより優先される', () {
        expect(
          DifficultyEstimator.estimateRank('設計書の作成'),
          QuestRank.A,
        );
      });

      test('SキーワードがBより優先される', () {
        expect(
          DifficultyEstimator.estimateRank('緊急の掃除'),
          QuestRank.S,
        );
      });
    });
  });
}
