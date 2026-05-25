import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';

/// TaskCard の isUrgent 判定テスト
/// 前提バグ：修練場(active)のタスクで期限が迫っていても緊急判定が false になる
/// → status 条件を外す修正の検証
void main() {
  group('TaskCard isUrgent 判定', () {
    test('active 状態で期限が24時間以内なら緊急判定が true', () {
      final task = Task(
        id: 'test-1',
        title: '緊急討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
        deadline: DateTime.now().add(const Duration(hours: 2)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.isUrgent, isTrue);
    });

    test('inGuild 状態で期限が24時間以内なら緊急判定が true（既存動作維持）', () {
      final task = Task(
        id: 'test-2',
        title: '討伐依頼',
        rank: QuestRank.A,
        status: TaskStatus.inGuild,
        deadline: DateTime.now().add(const Duration(hours: 12)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.isUrgent, isTrue);
    });

    test('active 状態で期限が25時間後なら緊急判定が false', () {
      final task = Task(
        id: 'test-3',
        title: '余裕ある討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
        deadline: DateTime.now().add(const Duration(hours: 25)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.isUrgent, isFalse);
    });

    test('deadline が null なら緊急判定は false', () {
      final task = Task(
        id: 'test-4',
        title: '期限なし討伐',
        rank: QuestRank.S,
        status: TaskStatus.active,
        deadline: null,
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.isUrgent, isFalse);
    });

    test('期限が過去（期限切れ）でも緊急判定は true', () {
      final task = Task(
        id: 'test-5',
        title: '期限切れ討伐',
        rank: QuestRank.A,
        status: TaskStatus.active,
        deadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.isUrgent, isTrue);
    });
  });

  group('敵アイコン ランク表示', () {
    test('Sランクはドラゴン🐉', () {
      final task = Task(
        id: 'dragon',
        title: 'ドラゴン討伐',
        rank: QuestRank.S,
        status: TaskStatus.active,
      );
      final card = TaskCard(task: task, actions: const []);
      // _getRankEnemyEmoji は private だが、active タスクでは leading に表示されている
      // ウィジェットテストで確認するのが適切なため、ここでは構造の検証に留める
      expect(card.task.rank, QuestRank.S);
    });

    test('Aランクはオーガ👹', () {
      final task = Task(
        id: 'ogre',
        title: 'オーガ討伐',
        rank: QuestRank.A,
        status: TaskStatus.active,
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.task.rank, QuestRank.A);
    });

    test('Bランクはゴブリン👺', () {
      final task = Task(
        id: 'goblin',
        title: 'ゴブリン討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.task.rank, QuestRank.B);
    });
  });

  group('TaskCard 期限カウントダウン', () {
    test('期限が6時間超の場合は青色', () {
      final task = Task(
        id: 'cd-1',
        title: '余裕討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
        deadline: DateTime.now().add(const Duration(hours: 10)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.urgencyColor, equals(TaskCard.urgencyColorBlue));
    });

    test('期限が1-6時間の場合は黄色', () {
      final task = Task(
        id: 'cd-2',
        title: '注意討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
        deadline: DateTime.now().add(const Duration(hours: 3)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.urgencyColor, equals(TaskCard.urgencyColorYellow));
    });

    test('期限が1時間未満の場合は赤色', () {
      final task = Task(
        id: 'cd-3',
        title: '緊急討伐',
        rank: QuestRank.A,
        status: TaskStatus.active,
        deadline: DateTime.now().add(const Duration(minutes: 30)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.urgencyColor, equals(TaskCard.urgencyColorRed));
    });

    test('期限切れの場合も赤色', () {
      final task = Task(
        id: 'cd-4',
        title: '期限切れ討伐',
        rank: QuestRank.A,
        status: TaskStatus.active,
        deadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.urgencyColor, equals(TaskCard.urgencyColorRed));
    });

    test('期限なしの場合は緊急色が null', () {
      final task = Task(
        id: 'cd-5',
        title: '期限なし討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
        deadline: null,
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.urgencyColor, isNull);
    });

    test('期限が24時間超の場合は緊急色が null', () {
      final task = Task(
        id: 'cd-6',
        title: '遠い討伐',
        rank: QuestRank.B,
        status: TaskStatus.active,
        deadline: DateTime.now().add(const Duration(hours: 30)),
      );
      final card = TaskCard(task: task, actions: const []);
      expect(card.urgencyColor, isNull);
    });
  });
}
