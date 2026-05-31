import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/data/real_griffon_estimator.dart';
import 'package:rpg_todo/features/shared/domain/griffon_estimator.dart';

void main() {
  group('RealGriffonEstimator.parseResponse', () {
    test('Sランク+見積もり時間をパース', () {
      final result = RealGriffonEstimator.parseResponse(
        'RANK: S\nMINUTES: 120\nREASON: 本番作業と判断',
      );
      expect(result.rank, QuestRank.S);
      expect(result.estimatedMinutes, 120);
      expect(result.source, EstimationSource.grffon);
    });

    test('Aランク+見積もり時間をパース', () {
      final result = RealGriffonEstimator.parseResponse(
        'RANK: A\nMINUTES: 45\nREASON: 設計作業と判断',
      );
      expect(result.rank, QuestRank.A);
      expect(result.estimatedMinutes, 45);
    });

    test('Bランク+見積もり時間をパース', () {
      final result = RealGriffonEstimator.parseResponse(
        'RANK: B\nMINUTES: 15\nREASON: 日常タスクと判断',
      );
      expect(result.rank, QuestRank.B);
      expect(result.estimatedMinutes, 15);
    });

    test('小文字のランク+見積もり時間をパース', () {
      final result = RealGriffonEstimator.parseResponse(
        'rank: s\nminutes: 90',
      );
      expect(result.rank, QuestRank.S);
      expect(result.estimatedMinutes, 90);
    });

    test('MINUTESがない場合estimatedMinutesはnull', () {
      final result = RealGriffonEstimator.parseResponse(
        'RANK: B\nREASON: 簡単',
      );
      expect(result.rank, QuestRank.B);
      expect(result.estimatedMinutes, isNull);
    });

    test('不明なランク文字列はBにフォールバック', () {
      final result = RealGriffonEstimator.parseResponse(
        'RANK: X\nMINUTES: 30',
      );
      expect(result.rank, QuestRank.B);
    });

    test('RANKがない場合はデフォルトB', () {
      final result = RealGriffonEstimator.parseResponse(
        'MINUTES: 50\nREASON: something',
      );
      expect(result.rank, QuestRank.B);
      expect(result.estimatedMinutes, 50);
    });

    test('空文字列はB', () {
      final result = RealGriffonEstimator.parseResponse('');
      expect(result.rank, QuestRank.B);
      expect(result.estimatedMinutes, isNull);
    });
  });

  group('RealGriffonEstimator', () {
    group('buildSystemPrompt', () {
      test('魔導書のシステムプロンプトに難易度基準が含まれる', () {
        final estimator = RealGriffonEstimator(apiKey: 'test-key');
        final prompt = estimator.buildSystemPrompt();
        expect(prompt, contains('魔導書（グリフォン）'));
        expect(prompt, contains('Sランク'));
        expect(prompt, contains('Aランク'));
        expect(prompt, contains('Bランク'));
        expect(prompt, contains('RANK:'));
        expect(prompt, contains('MINUTES:'));
        expect(prompt, contains('REASON:'));
      });
    });

    group('buildUserMessage', () {
      test('過去タスク履歴ありの場合', () {
        final estimator = RealGriffonEstimator(apiKey: 'test-key');
        final message = estimator.buildUserMessage(
          '本番デプロイ',
          ['週次レポート', 'コードレビュー', '買い物'],
        );
        expect(message, contains('本番デプロイ'));
        expect(message, contains('週次レポート'));
        expect(message, contains('コードレビュー'));
        expect(message, contains('買い物'));
      });

      test('過去タスク履歴なしの場合', () {
        final estimator = RealGriffonEstimator(apiKey: 'test-key');
        final message = estimator.buildUserMessage('新規タスク', []);
        expect(message, contains('新規タスク'));
        expect(message, contains('過去のタスク履歴なし'));
      });
    });

    group('estimate - API失敗時のフォールバック', () {
      test('HTTP 500 エラー時はキーワード推定にフォールバック', () async {
        final client = MockClient((request) async {
          return http.Response('Server Error', 500);
        });
        final estimator = RealGriffonEstimator(
          httpClient: client,
          apiKey: 'test-key',
        );

        final result = await estimator.estimate('緊急バグ修正', []);

        expect(result.rank, QuestRank.S);
        expect(result.source, EstimationSource.keyword);
        expect(result.estimatedMinutes, isNull);
      });

      test('空レスポンス時はフォールバック', () async {
        final client = MockClient((request) async {
          return http.Response('{"choices": []}', 200);
        });
        final estimator = RealGriffonEstimator(
          httpClient: client,
          apiKey: 'test-key',
        );

        final result = await estimator.estimate('散歩', []);

        expect(result.rank, QuestRank.B);
        expect(result.source, EstimationSource.keyword);
      });

      test('例外発生時はフォールバック', () async {
        final client = MockClient((request) async {
          throw Exception('Network error');
        });
        final estimator = RealGriffonEstimator(
          httpClient: client,
          apiKey: 'test-key',
        );

        final result = await estimator.estimate('設計書作成', []);

        expect(result.rank, QuestRank.B);
        expect(result.source, EstimationSource.keyword);
      });
    });
  });
}
