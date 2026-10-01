import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/domain/task_template.dart';

void main() {
  group('TaskTemplate モデル', () {
    test('空の定型名は ArgumentError', () {
      expect(() => TaskTemplate(id: 't1', name: '  ', title: 'X'),
          throwsArgumentError);
    });

    test('空のクエスト名は ArgumentError', () {
      expect(() => TaskTemplate(id: 't1', name: '定型', title: ''),
          throwsArgumentError);
    });

    test('JSON 往復で等価', () {
      final t = TaskTemplate(
        id: 't1',
        name: '朝のあいさつ',
        title: '朝のあいさつクエスト',
        rank: QuestRank.A,
        repeatInterval: RepeatInterval.weekly,
        repeatWeekdays: [1, 3, 5],
        subTaskTitles: ['洗面', '着替え'],
        targetTimeMinutes: 10,
      );
      final restored = TaskTemplate.fromJson(t.toJson());
      expect(restored, t);
    });

    test('repeatWeekdays の範囲外・重複は除去される', () {
      final t = TaskTemplate(
          id: 't1',
          name: 'n',
          title: 'x',
          repeatWeekdays: [0, 3, 3, 8, 7]);
      expect(t.repeatWeekdays, [3, 7]);
    });

    test('subTaskTitles の空行は除去・前後空白トリム', () {
      final t = TaskTemplate(
          id: 't1',
          name: 'n',
          title: 'x',
          subTaskTitles: ['  a ', '', '  ', 'b']);
      expect(t.subTaskTitles, ['a', 'b']);
    });

    test('copyWith で targetTime を解除できる', () {
      final t = TaskTemplate(
          id: 't1', name: 'n', title: 'x', targetTimeMinutes: 5);
      final cleared = t.copyWith(clearTargetTime: true);
      expect(cleared.targetTimeMinutes, isNull);
      expect(t.targetTimeMinutes, 5);
    });
  });

  group('TaskTemplateService.normalizeName', () {
    const service = TaskTemplateService();

    test('全角英数・全角スペース→半角・小文字化・空白圧縮', () {
      expect(service.normalizeName('Ａ　ＢＣｄ'), 'a bcd');
      expect(service.normalizeName('  朝の　あいさつ '), '朝の あいさつ');
    });
  });

  group('TaskTemplateService.validateNew', () {
    const service = TaskTemplateService();
    final existing = [
      TaskTemplate(id: 'a', name: '朝のあいさつ', title: 'x'),
    ];

    test('空名は問題を返す', () {
      expect(service.validateNew(name: '  ', existing: existing),
          contains('定型名が空です'));
    });

    test('正規化同名は重複判定', () {
      expect(
          service.validateNew(name: '朝の　あいさつ', existing: existing),
          contains('同名の定型が既に存在します'));
      expect(service.validateNew(name: '夜のあいさつ', existing: existing),
          isEmpty);
    });
  });

  group('TaskTemplateService.buildTask / fromTask', () {
    const service = TaskTemplateService();

    test('buildTask は inGuild・未完了サブタスクの新規クエストを組立', () {
      final t = TaskTemplate(
        id: 't1',
        name: '朝',
        title: '朝のクエスト',
        rank: QuestRank.S,
        repeatInterval: RepeatInterval.weekly,
        repeatWeekdays: [1],
        subTaskTitles: ['a', 'b'],
        targetTimeMinutes: 15,
      );
      final task = service.buildTask(t, id: 'task-1');
      expect(task.id, 'task-1');
      expect(task.title, '朝のクエスト');
      expect(task.rank, QuestRank.S);
      expect(task.status, TaskStatus.inGuild);
      expect(task.isCompleted, isFalse);
      expect(task.repeatWeekdays, [1]);
      expect(task.subTasks.map((s) => s.title).toList(), ['a', 'b']);
      expect(task.subTasks.every((s) => !s.isCompleted), isTrue);
      expect(task.targetTimeMinutes, 15);
    });

    test('fromTask は実行状態を落として定型化する', () {
      final task = Task(
        id: 'orig',
        title: '掃除',
        status: TaskStatus.active,
        isCompleted: false,
        rank: QuestRank.B,
        repeatInterval: RepeatInterval.daily,
        subTasks: [
          SubTask(title: '床', isCompleted: true),
          SubTask(title: '机', isCompleted: false),
        ],
        targetTimeMinutes: 20,
        lastCompletedAt: DateTime(2026, 9, 1),
      );
      final t = service.fromTask(id: 't9', name: '掃除定型', task: task);
      expect(t.id, 't9');
      expect(t.name, '掃除定型');
      expect(t.title, '掃除');
      expect(t.rank, QuestRank.B);
      expect(t.repeatInterval, RepeatInterval.daily);
      expect(t.subTaskTitles, ['床', '机']);
      expect(t.targetTimeMinutes, 20);
      // fromTask → buildTask で新規クエストに循環できる
      final rebuilt = service.buildTask(t, id: 'task-2');
      expect(rebuilt.status, TaskStatus.inGuild);
      expect(rebuilt.subTasks.every((s) => !s.isCompleted), isTrue);
    });
  });

  group('TaskTemplateService.sortByName / searchByName', () {
    const service = TaskTemplateService();
    final templates = [
      TaskTemplate(id: 'c', name: '夜の勤行', title: '夜'),
      TaskTemplate(id: 'a', name: 'あさの勤行', title: '朝'),
      TaskTemplate(id: 'b', name: 'うんどう', title: '運動'),
    ];

    test('sortByName は非破壊・正規化名昇順・同値は id 昇順', () {
      final sorted = service.sortByName(templates);
      expect(sorted.map((t) => t.id).toList(), ['a', 'b', 'c']);
      expect(templates.map((t) => t.id).toList(), ['c', 'a', 'b'],
          reason: '入力リストは非破壊');
      final tie = [
        TaskTemplate(id: 'z', name: 'X', title: 'x'),
        TaskTemplate(id: 'y', name: 'ｘ', title: 'x'),
      ];
      expect(service.sortByName(tie).map((t) => t.id).toList(), ['y', 'z']);
    });

    test('searchByName は名前・クエスト名の部分一致（正規化）', () {
      expect(
          service.searchByName(templates: templates, query: '勤行').length, 2);
      expect(service.searchByName(templates: templates, query: '運動').first.id,
          'b');
      expect(
          service.searchByName(templates: templates, query: '　').length, 3,
          reason: '空クエリ（正規化で空）は全件');
      expect(service.searchByName(templates: templates, query: '存在しない'),
          isEmpty);
    });

    test('絞り込み × ソートの合成は部分集合に適用される', () {
      final filtered = service.searchByName(templates: templates, query: '勤行');
      final sorted = service.sortByName(filtered);
      expect(sorted.map((t) => t.id).toList(), ['a', 'c'],
          reason: 'ソートは母集合ではなく絞り込み後の部分集合に適用');
    });
  });

  group('TaskTemplateRepository', () {
    test('InMemory は保存した定型を復元する', () async {
      final repo = InMemoryTaskTemplateRepository();
      await repo.save([TaskTemplate(id: 't1', name: 'n', title: 'x')]);
      final loaded = await repo.load();
      expect(loaded.length, 1);
      expect(loaded.first.id, 't1');
    });
  });
}
