import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_tag_service.dart';

Task _task(String id, {String title = 'q', List<String> tags = const []}) =>
    Task(id: id, title: title, tags: List<String>.of(tags));

void main() {
  group('QuestTagService.normalize', () {
    test('trim する', () {
      expect(QuestTagService.normalize('  買い物  '), '買い物');
    });

    test('全角英数字を半角へ変換する', () {
      expect(QuestTagService.normalize('ＡＢＣ１２３'), 'ABC123');
    });

    test('全角スペースを半角へ変換する', () {
      expect(QuestTagService.normalize('仕事　家事'), '仕事 家事');
    });

    test('連続空白を単一化する', () {
      expect(QuestTagService.normalize('a   b\tc'), 'a b c');
    });

    test('大文字小文字は保存時にそのまま残す', () {
      expect(QuestTagService.normalize('Work'), 'Work');
    });

    test('空文字は空文字のまま', () {
      expect(QuestTagService.normalize('   '), '');
    });
  });

  group('QuestTagService.validateNew', () {
    test('空は empty', () {
      expect(QuestTagService.validateNew('   ', const []),
          QuestTagValidation.empty);
    });

    test('12文字は ok', () {
      expect(QuestTagService.validateNew('あ' * 12, const []),
          QuestTagValidation.ok);
    });

    test('13文字は tooLong', () {
      expect(QuestTagService.validateNew('あ' * 13, const []),
          QuestTagValidation.tooLong);
    });

    test('既存と大文字小文字無視で一致すれば duplicate', () {
      expect(QuestTagService.validateNew('work', const ['Work']),
          QuestTagValidation.duplicate);
    });

    test('正規化後に既存と一致すれば duplicate', () {
      expect(QuestTagService.validateNew('ＷＯＲＫ', const ['work']),
          QuestTagValidation.duplicate);
    });

    test('既存と別なら ok', () {
      expect(QuestTagService.validateNew('work', const ['home']),
          QuestTagValidation.ok);
    });
  });

  group('QuestTagService.uniqueTags', () {
    test('重複を大文字小文字無視で除去し初出順を保つ', () {
      expect(
        QuestTagService.uniqueTags(['b', 'A', 'b', 'a', 'c']),
        ['b', 'A', 'c'],
      );
    });

    test('正規化したタグを返す', () {
      expect(QuestTagService.uniqueTags([' ＷＯＲＫ ', 'work']), ['WORK']);
    });

    test('空/空白のみは除外する', () {
      expect(QuestTagService.uniqueTags(['', '  ', 'x']), ['x']);
    });
  });

  group('QuestTagService.counts', () {
    test('件数降順で集計する', () {
      final tasks = [
        _task('1', tags: ['a', 'b']),
        _task('2', tags: ['b']),
        _task('3', tags: ['b', 'c']),
      ];
      final result = QuestTagService.counts(tasks);
      expect(result.map((e) => e.tag).toList(), ['b', 'a', 'c']);
      expect(result.map((e) => e.count).toList(), [3, 1, 1]);
    });

    test('同件数ならタグ名昇順', () {
      final tasks = [
        _task('1', tags: ['zeta']),
        _task('2', tags: ['alpha']),
      ];
      expect(QuestTagService.counts(tasks).map((e) => e.tag).toList(),
          ['alpha', 'zeta']);
    });

    test('正規化後の同値は元のタグ文字列昇順、同値なら初出順', () {
      final tasks = [
        _task('1', tags: ['ＷＯＲＫ']),
        _task('2', tags: ['work']),
      ];
      final result = QuestTagService.counts(tasks);
      expect(result.length, 2);
      // 'WORK' < 'work' (コードユニット順)
      expect(result.map((e) => e.tag).toList(), ['WORK', 'work']);
      expect(result.map((e) => e.count).toList(), [1, 1]);
    });

    test('空文字と空白のみのタグは無視する', () {
      final tasks = [
        _task('1', tags: ['', '  ', 'ok']),
      ];
      expect(QuestTagService.counts(tasks).map((e) => e.tag).toList(), ['ok']);
    });

    test('入力を破壊しない', () {
      final tasks = [_task('1', tags: ['b', 'a'])];
      QuestTagService.counts(tasks);
      expect(tasks.first.tags, ['b', 'a']);
    });

    test('0件なら空', () {
      expect(QuestTagService.counts(const []), isEmpty);
    });

    test('タグ無しタスクのみなら空', () {
      expect(QuestTagService.counts([_task('1')]), isEmpty);
    });
  });

  group('QuestTagService.matchesTags', () {
    test('空集合は全通過', () {
      expect(QuestTagService.matchesTags(_task('1'), const {}), isTrue);
    });

    test('いずれかを持つなら true（OR）', () {
      final t = _task('1', tags: ['a', 'b']);
      expect(QuestTagService.matchesTags(t, {'b', 'z'}), isTrue);
    });

    test('どれも持たなければ false', () {
      expect(QuestTagService.matchesTags(_task('1', tags: ['a']), {'z'}),
          isFalse);
    });

    test('大文字小文字無視で一致する', () {
      expect(QuestTagService.matchesTags(_task('1', tags: ['Work']), {'work'}),
          isTrue);
    });

    test('部分一致では一致しない（完全一致）', () {
      expect(QuestTagService.matchesTags(_task('1', tags: ['workshop']), {'work'}),
          isFalse);
    });
  });

  group('QuestTagService.filterByTags', () {
    test('OR で絞り込む', () {
      final tasks = [
        _task('1', tags: ['a']),
        _task('2', tags: ['b']),
        _task('3', tags: ['c']),
      ];
      final result = QuestTagService.filterByTags(tasks, {'a', 'c'});
      expect(result.map((e) => e.id).toList(), ['1', '3']);
    });

    test('空集合は入力をそのまま返す', () {
      final tasks = [_task('1', tags: ['a'])];
      expect(QuestTagService.filterByTags(tasks, const {}), same(tasks));
    });
  });

  group('QuestTagService.withTag', () {
    test('タグを追加し元リストを破壊しない', () {
      final current = ['a'];
      final next = QuestTagService.withTag(current, 'b');
      expect(next, ['a', 'b']);
      expect(current, ['a']);
    });

    test('既に同名（大文字小文字無視）があれば内容そのまま', () {
      final current = ['Work'];
      expect(QuestTagService.withTag(current, 'work'), ['Work']);
    });

    test('正規化して追加する', () {
      expect(QuestTagService.withTag(const [], ' ＷＯＲＫ '), ['WORK']);
    });

    test('空タグは追加しない', () {
      expect(QuestTagService.withTag(const ['a'], '   '), ['a']);
    });
  });

  group('QuestTagService.withoutTag', () {
    test('大文字小文字無視で削除し元リストを破壊しない', () {
      final current = ['Work', 'home'];
      final next = QuestTagService.withoutTag(current, 'work');
      expect(next, ['home']);
      expect(current, ['Work', 'home']);
    });

    test('存在しないタグなら内容そのまま', () {
      expect(QuestTagService.withoutTag(const ['a'], 'z'), ['a']);
    });
  });
}
