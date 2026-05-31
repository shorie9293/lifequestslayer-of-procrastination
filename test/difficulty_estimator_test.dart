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
      test('「データ移行計画」でA（複合キーワード: 移行+計画）', () {
        expect(DifficultyEstimator.estimateRank('データ移行計画'), QuestRank.A);
      });

      test('「新機能の実装＋API連携」でA（複合キーワード）', () {
        expect(
          DifficultyEstimator.estimateRank('新機能の実装＋API連携'),
          QuestRank.A,
        );
      });

      test('「FlutterでのUI実装」でA（複合キーワード）', () {
        expect(
          DifficultyEstimator.estimateRank('FlutterでのUI実装'),
          QuestRank.A,
        );
      });

      test('長文＋StepパターンでA（キーワードなし複雑パターン）', () {
        expect(
          DifficultyEstimator.estimateRank(
              '買い物リストの作成からStep2買うものの整理までを実施するの'),
          QuestRank.A,
        );
      });

      test('長文＋連携パターンでA（キーワードなし複雑パターン）', () {
        expect(
          DifficultyEstimator.estimateRank(
              '来週のタスクを洗い出しからスケジュール調整までの準備作業を進める'),
          QuestRank.A,
        );
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

      test('「新機能の実装」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('新機能の実装'), QuestRank.B);
      });

      test('「設計ドキュメントの作成」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('設計ドキュメントの作成'),
            QuestRank.B);
      });

      test('「コードレビュー」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('コードレビュー'), QuestRank.B);
      });

      test('「分析レポートの作成」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('分析レポートの作成'),
            QuestRank.B);
      });

      test('「システムの最適化」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('システムの最適化'), QuestRank.B);
      });

      test('「リファクタリング」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('リファクタリング'), QuestRank.B);
      });

      test('「テストケースの作成」でB（Aキーワード1つだけ＋短文）', () {
        expect(DifficultyEstimator.estimateRank('テストケースの作成'),
            QuestRank.B);
      });

      test('「簡単な修正」でB（修正はAキーワードから除外された）', () {
        expect(DifficultyEstimator.estimateRank('簡単な修正'), QuestRank.B);
      });

      test('「勉強する」でB（除外されたキーワード）', () {
        expect(DifficultyEstimator.estimateRank('勉強する'), QuestRank.B);
      });

      test('「買い物と掃除と洗濯」でB（日常タスクの列挙）', () {
        expect(DifficultyEstimator.estimateRank('買い物と掃除と洗濯'),
            QuestRank.B);
      });

      test('Aキーワードなしのランダム文字列はB（16文字超でもB）', () {
        expect(DifficultyEstimator.estimateRank('あいうえおかきくけこさしすせそた'),
            QuestRank.B);
      });

      test('S/Aキーワードを含まない20文字の繰り返しはB', () {
        final longTitle = List.filled(20, 'あ').join();
        expect(DifficultyEstimator.estimateRank(longTitle), QuestRank.B);
      });

      test('英語タイトルで24文字でもキーワードなしならB', () {
        expect(
          DifficultyEstimator.estimateRank('This is a long task title'),
          QuestRank.B,
        );
      });
    });

    group('優先順位', () {
      test('Sキーワードがあれば文字数に関係なくS', () {
        // 「緊急」が含まれているため、短くてもS
        expect(DifficultyEstimator.estimateRank('緊急'), QuestRank.S);
      });

      test('Aキーワードがなくて長くてもB', () {
        expect(
          DifficultyEstimator.estimateRank('あいうえおかきくけこさしすせそた'),
          QuestRank.B,
        );
      });

      test('Aキーワード1つだけの短文はB', () {
        expect(DifficultyEstimator.estimateRank('実装'), QuestRank.B);
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

      test('Aキーワードを1つ含む長文（21文字超）はA', () {
        expect(
          DifficultyEstimator.estimateRank('先月のプロジェクト進捗報告について話し合う'),
          QuestRank.A,
        );
      });

      test('英語タイトルで短ければB', () {
        expect(DifficultyEstimator.estimateRank('Read book'), QuestRank.B);
      });
    });
  });
}
