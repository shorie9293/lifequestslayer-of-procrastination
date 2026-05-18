import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/griffon_estimator.dart';
import 'package:rpg_todo/features/shared/domain/difficulty_estimator.dart';

/// テスト用 FakeGriffonEstimator — 過去タスク名と推定結果のマップを持つ
class FakeGriffonEstimator implements GriffonEstimator {
  final Map<String, GriffonEstimation> _estimations;

  FakeGriffonEstimator(this._estimations);

  @override
  Future<GriffonEstimation> estimate(
    String title,
    List<String> pastTaskTitles,
  ) async {
    if (_estimations.containsKey(title)) {
      return _estimations[title]!;
    }
    // デフォルト: キーワードベースにフォールバック
    final rank = DifficultyEstimator.estimateRank(title);
    return GriffonEstimation(rank: rank, estimatedMinutes: null);
  }
}

void main() {
  group('GriffonEstimator', () {
    late GriffonEstimator estimator;

    setUp(() {
      estimator = FakeGriffonEstimator({
        '本番デプロイの最終確認と手順書作成':
            GriffonEstimation(rank: QuestRank.S, estimatedMinutes: 120),
        '週次レポートの作成と提出':
            GriffonEstimation(rank: QuestRank.A, estimatedMinutes: 45),
        '買い物リストの作成':
            GriffonEstimation(rank: QuestRank.B, estimatedMinutes: 15),
        'コードレビュー':
            GriffonEstimation(rank: QuestRank.A, estimatedMinutes: 30),
      });
    });

    group('AI推定', () {
      test('過去の類似タスクからSランク＋見積もり時間を返す', () async {
        final result = await estimator.estimate(
          '本番デプロイの最終確認と手順書作成',
          ['本番デプロイ', '手順書作成', 'リリース作業'],
        );
        expect(result.rank, QuestRank.S);
        expect(result.estimatedMinutes, 120);
      });

      test('過去の類似タスクからAランク＋見積もり時間を返す', () async {
        final result = await estimator.estimate(
          '週次レポートの作成と提出',
          ['月次レポート', '資料作成'],
        );
        expect(result.rank, QuestRank.A);
        expect(result.estimatedMinutes, 45);
      });

      test('過去の類似タスクからBランク＋見積もり時間を返す', () async {
        final result = await estimator.estimate(
          '買い物リストの作成',
          ['買い物', '掃除'],
        );
        expect(result.rank, QuestRank.B);
        expect(result.estimatedMinutes, 15);
      });

      test('AI推定がなくてもキーワードベース推定にフォールバック', () async {
        final result = await estimator.estimate('未知のタスク', []);
        expect(result.rank, isNotNull);
        expect(result.estimatedMinutes, isNull);
      });
    });

    group('見積もり時間', () {
      test('estimatedMinutesがnullでもランクは返る', () async {
        final result = await estimator.estimate('未知のタスク', []);
        expect(result.rank, isA<QuestRank>());
        expect(result.estimatedMinutes, isNull);
      });
    });
  });

  group('DifficultyEstimator with AI fallback', () {
    late GriffonEstimator griffonEstimator;
    final pastTasks = ['本番デプロイ', '週次レポート', '買い物', 'コードレビュー'];

    setUp(() {
      griffonEstimator = FakeGriffonEstimator({
        '本番デプロイの最終確認と手順書作成':
            GriffonEstimation(rank: QuestRank.S, estimatedMinutes: 120),
        '週次レポートの作成と提出':
            GriffonEstimation(rank: QuestRank.A, estimatedMinutes: 45),
        '買い物リストの作成':
            GriffonEstimation(rank: QuestRank.B, estimatedMinutes: 15),
        'コードレビュー':
            GriffonEstimation(rank: QuestRank.A, estimatedMinutes: 30),
      });
    });

    test('griffonが有効な場合、AI推定でSランクと見積もり時間を取得', () async {
      final result = await DifficultyEstimator.estimateWithAI(
        '本番デプロイの最終確認と手順書作成',
        pastTasks,
        griffonEstimator,
      );
      expect(result.rank, QuestRank.S);
      expect(result.estimatedMinutes, 120);
      expect(result.source, EstimationSource.grffon);
    });

    test('griffonが有効な場合、AI推定でAランクと見積もり時間を取得', () async {
      final result = await DifficultyEstimator.estimateWithAI(
        '週次レポートの作成と提出',
        pastTasks,
        griffonEstimator,
      );
      expect(result.rank, QuestRank.A);
      expect(result.estimatedMinutes, 45);
      expect(result.source, EstimationSource.grffon);
    });

    test('griffonが有効な場合、AI推定でBランクと見積もり時間を取得', () async {
      final result = await DifficultyEstimator.estimateWithAI(
        '買い物リストの作成',
        pastTasks,
        griffonEstimator,
      );
      expect(result.rank, QuestRank.B);
      expect(result.estimatedMinutes, 15);
      expect(result.source, EstimationSource.grffon);
    });

    test('griffonがnullの場合、キーワードベースにフォールバック', () async {
      final result = await DifficultyEstimator.estimateWithAI(
        '緊急のバグ修正',
        pastTasks,
        null,
      );
      expect(result.rank, QuestRank.S);
      expect(result.estimatedMinutes, isNull);
      expect(result.source, EstimationSource.keyword);
    });

    test('見積もり時間なしでもランク推定は動作', () async {
      // FakeGriffonEstimator が知らないタスクの場合、estimatedMinutes は null
      final result = await DifficultyEstimator.estimateWithAI(
        '未知のタスク',
        [],
        griffonEstimator,
      );
      expect(result.rank, isNotNull);
      expect(result.source, isNotNull);
    });

    test('キーワードのみ使用時の source は keyword', () {
      final result = DifficultyEstimator.estimateRankWithSource('緊急のバグ修正');
      expect(result.rank, QuestRank.S);
      expect(result.source, EstimationSource.keyword);
    });

    test('キーワードのみ使用時、estimatedMinutes は null', () {
      // 「設計ドキュメントの作成」はAランクキーワード「設計」を含む
      final result =
          DifficultyEstimator.estimateRankWithSource('設計ドキュメントの作成');
      expect(result.rank, QuestRank.A);
      expect(result.estimatedMinutes, isNull);
      expect(result.source, EstimationSource.keyword);
    });
  });
}
