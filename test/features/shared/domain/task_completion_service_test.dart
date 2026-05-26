import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

void main() {
  group('TaskCompletionService - 期限切れペナルティ', () {
    late TaskCompletionService service;

    setUp(() {
      service = TaskCompletionService();
      // テスト用のクイズデータをセット
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'normal_q1',
          question: '通常問題',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 10,
        ),
        const QuizQuestion(
          id: 'hard_q1',
          question: '難しい問題',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 3,
          expBonusPercent: 50,
        ),
        const QuizQuestion(
          id: 'hard_q2',
          question: '超難問',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          expBonusPercent: 80,
        ),
      ]);
      QuizService.probability = 0.0; // 通常抽選は当たらないように
    });

    tearDown(() {
      QuizService.probability = 0.30;
    });

    Task makeTask({
      required String id,
      QuestRank rank = QuestRank.B,
      DateTime? deadline,
    }) {
      return Task(
        id: id,
        title: 'テストタスク',
        status: TaskStatus.active,
        rank: rank,
        deadline: deadline,
      );
    }

    test('期限切れタスク完了時に強制クイズ（drawHardQuizQuestion）が呼ばれる', () {
      final task = makeTask(
        id: 'overdue-1',
        deadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: true,
      );

      expect(result, isNotNull);
      expect(result!.quizQuestion, isNotNull,
          reason: '期限切れタスクではクイズが強制発動されるべき');
      expect(result.bonusMessages,
          anyElement(contains('刻の番人')),
          reason: '期限切れメッセージがbonusMessagesに含まれるべき');
    });

    test('期限切れタスクでknowledgeQuestEnabled=falseでもクイズが発動する', () {
      final task = makeTask(
        id: 'overdue-2',
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(result!.quizQuestion, isNotNull,
          reason: 'knowledgeQuestEnabled=falseでも期限切れなら強制クイズ');
      expect(result.bonusMessages,
          anyElement(contains('刻の番人')),
          reason: '期限切れメッセージが含まれるべき');
    });

    test('期限切れでないタスクでは通常通りクイズ抽選（確率0%なのでnull）', () {
      final futureDeadline = DateTime.now().add(const Duration(days: 1));
      final task = makeTask(
        id: 'not-overdue',
        deadline: futureDeadline,
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: true,
      );

      expect(result, isNotNull);
      // probability=0.0 なので抽選は当たらない
      expect(result!.quizQuestion, isNull);
      expect(result.bonusMessages,
          isNot(anyElement(contains('期限'))),
          reason: '期限内のタスクには期限切れメッセージがないべき');
    });

    test('deadlineがnullのタスクは期限切れ処理なし', () {
      final task = makeTask(
        id: 'no-deadline',
        deadline: null,
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: true,
      );

      expect(result, isNotNull);
      expect(result!.quizQuestion, isNull);
      expect(result.bonusMessages,
          isNot(anyElement(contains('期限'))),
          reason: 'deadlineなしタスクには期限切れメッセージがないべき');
    });

    test('期限切れタスク完了時にEXPが減少するペナルティがある', () {
      // Bランク基本EXP=100
      final task = makeTask(
        id: 'overdue-penalty',
        rank: QuestRank.B,
        deadline: DateTime.now().subtract(const Duration(days: 2)),
      );
      final player = Player();
      player.jobLevels[player.currentJob] = 1;

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // 通常100だが、期限切れペナルティで減少
      expect(result!.expGain, lessThan(100),
          reason: '期限切れタスクではEXPが減少するペナルティがあるべき');
    });

    test('期限切れタスクではcoinsも半減する（倍ペナルティ）', () {
      final task = makeTask(
        id: 'overdue-coin-penalty',
        rank: QuestRank.A, // Aランク基本coins=30
        deadline: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final player = Player();
      player.jobLevels[player.currentJob] = 1;

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // Aランク基本30文 → 期限切れで半減 → 15文（小数点切捨て）
      expect(result!.coinsGained, equals(15),
          reason: '期限切れタスクではcoinsも半減（倍ペナルティ）すべき');
    });

    test('期限内・残り1時間以内でReverseBonus（XP 1.5倍）が発動する', () {
      final task = makeTask(
        id: 'reverse-bonus',
        rank: QuestRank.B,
        deadline: DateTime.now().add(const Duration(minutes: 30)),
      );
      final player = Player();
      player.jobLevels[player.currentJob] = 1;

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // Bランク基本100 * 1.5 = 150
      expect(result!.expGain, equals(150),
          reason: '期限内・残り1時間以内はReverseBonusでXP1.5倍');
      expect(result.bonusMessages,
          anyElement(contains('ギリギリ')),
          reason: 'ReverseBonusのボーナスメッセージが含まれるべき');
    });

    test('期限内・残り2時間ではReverseBonusは発動しない', () {
      final task = makeTask(
        id: 'no-bonus-2h',
        rank: QuestRank.B,
        deadline: DateTime.now().add(const Duration(hours: 2)),
      );
      final player = Player();
      player.jobLevels[player.currentJob] = 1;

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // Bランク基本100（ボーナスなし）
      expect(result!.expGain, equals(100),
          reason: '残り2時間ではReverseBonusは発動しない');
      expect(result.bonusMessages,
          isNot(anyElement(contains('ギリギリ'))),
          reason: 'ボーナスメッセージは含まれないべき');
    });

    test('期限切れタスクではisOverdueBoss=trueが返る', () {
      final task = makeTask(
        id: 'overdue-boss-flag',
        deadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(result!.isOverdueBoss, isTrue,
          reason: '期限切れタスクではisOverdueBoss=trueが返るべき');
    });

    test('期限内タスクではisOverdueBoss=falseが返る', () {
      final task = makeTask(
        id: 'normal-boss-flag',
        deadline: DateTime.now().add(const Duration(days: 1)),
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(result!.isOverdueBoss, isFalse,
          reason: '期限内タスクではisOverdueBoss=falseが返るべき');
    });
  });

  group('QuizService - drawHardQuizQuestion', () {
    setUp(() {
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'easy',
          question: '簡単',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 10,
        ),
        const QuizQuestion(
          id: 'medium',
          question: '普通',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          expBonusPercent: 30,
        ),
        const QuizQuestion(
          id: 'hard',
          question: '難しい',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 2,
          expBonusPercent: 50,
        ),
        const QuizQuestion(
          id: 'very_hard',
          question: '超難問',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 3,
          expBonusPercent: 80,
        ),
      ]);
    });

    test('drawHardQuizQuestionは必ず問題を返す（確率100%）', () {
      final question = QuizService.drawHardQuizQuestion();
      expect(question, isNotNull);
    });

    test('drawHardQuizQuestionはexpBonusPercentが高い問題を優先する', () {
      // 複数回呼び出して、高い確率で高ボーナス問題が選ばれることを確認
      final results = <int>[];
      for (int i = 0; i < 50; i++) {
        final q = QuizService.drawHardQuizQuestion();
        if (q != null) {
          results.add(q.expBonusPercent);
        }
      }
      // 平均が30%超であること（単純ランダムなら平均42.5、難問優先ならそれ以上）
      final avg = results.fold(0, (a, b) => a + b) / results.length;
      expect(avg, greaterThan(30.0),
          reason: 'hard drawは高EXPボーナスの問題を優先すべき (avg=$avg)');
    });

    test('drawHardQuizQuestionは問題が空ならnullを返す', () {
      QuizService.setQuestions([]);
      final question = QuizService.drawHardQuizQuestion();
      expect(question, isNull);
    });
  });
}
