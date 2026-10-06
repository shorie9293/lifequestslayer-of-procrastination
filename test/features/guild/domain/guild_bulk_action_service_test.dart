// 寄合所のクエスト一括操作（改善提案 #91）— 純粋ドメイン層の試練
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_bulk_action.dart';

void main() {
  final now = DateTime(2026, 10, 6, 9);

  Task guild(String id,
      {DateTime? deadline, bool completed = false, TaskStatus? status}) {
    final t = Task(
      id: id,
      title: 'クエスト$id',
      status: status ?? TaskStatus.inGuild,
      isCompleted: completed,
      deadline: deadline,
    );
    return t;
  }

  group('GuildBulkActionService.selectableTasks', () {
    test('未受注かつ未完了のみ選択対象になる', () {
      final tasks = [
        guild('a'),
        guild('b', completed: true),
        guild('c', status: TaskStatus.active),
      ];
      final r = GuildBulkActionService.selectableTasks(tasks);
      expect(r.map((t) => t.id), ['a']);
    });

    test('空リストでも例外を投げない', () {
      expect(GuildBulkActionService.selectableTasks(const []), isEmpty);
    });
  });

  group('GuildBulkActionService.buildPlan', () {
    test('選択IDのうち対象可能なものだけを計画に含める', () {
      final tasks = [guild('a'), guild('b'), guild('c', status: TaskStatus.active)];
      final plan = GuildBulkActionService.buildPlan(
        tasks,
        {'a', 'b', 'c', 'unknown'},
        GuildBulkAction.delete,
      );
      expect(plan.targetIds, containsAll(['a', 'b']));
      expect(plan.targetIds, isNot(contains('c')));
      expect(plan.targetIds, isNot(contains('unknown')));
      expect(plan.skippedIds, containsAll(['c', 'unknown']));
    });

    test('plan.label に操作名と件数が入る', () {
      final plan = GuildBulkActionService.buildPlan(
          [guild('a')], {'a'}, GuildBulkAction.accept);
      expect(plan.label, contains('出発'));
      expect(plan.label, contains('1'));
    });
  });

  group('GuildBulkActionService.postponedDeadline', () {
    test('期限あり: 既存期限からN日延長する', () {
      final t = guild('a', deadline: DateTime(2026, 10, 10));
      final d = GuildBulkActionService.postponedDeadline(t, 7, now);
      expect(d, DateTime(2026, 10, 17));
    });

    test('期限なし: 基準時刻からN日後を新たな期限にする', () {
      final t = guild('a');
      final d = GuildBulkActionService.postponedDeadline(t, 3, now);
      expect(d, DateTime(2026, 10, 9, 9));
    });

    test('0日以下の延期は ArgumentError', () {
      final t = guild('a');
      expect(() => GuildBulkActionService.postponedDeadline(t, 0, now),
          throwsArgumentError);
      expect(() => GuildBulkActionService.postponedDeadline(t, -1, now),
          throwsArgumentError);
    });
  });

  group('GuildBulkAction', () {
    test('label は日本語・fromStorageKey は未知で null', () {
      expect(GuildBulkAction.accept.label, '出発');
      expect(GuildBulkAction.postpone.label, '延期');
      expect(GuildBulkAction.delete.label, '破棄');
      expect(GuildBulkAction.fromStorageKey('postpone'), GuildBulkAction.postpone);
      expect(GuildBulkAction.fromStorageKey('unknown'), isNull);
      expect(GuildBulkAction.fromStorageKey(null), isNull);
    });
  });
}
