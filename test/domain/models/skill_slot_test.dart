import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';

void main() {
  group('EquippedSkill', () {
    test('Construction and properties', () {
      final eq = EquippedSkill(skill: JobSkill.warriorCombo);
      expect(eq.skill, JobSkill.warriorCombo);
    });

    test('Equality', () {
      final a = EquippedSkill(skill: JobSkill.warriorCombo);
      final b = EquippedSkill(skill: JobSkill.warriorCombo);
      final c = EquippedSkill(skill: JobSkill.clericStreak);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('fromJson / toJson round trip', () {
      final original = EquippedSkill(skill: JobSkill.wizardProject);
      final json = original.toJson();
      final restored = EquippedSkill.fromJson(json);
      expect(restored.skill, original.skill);
    });
  });

  group('ProjectGroup', () {
    test('Construction with default values', () {
      final pg = ProjectGroup(name: 'テストプロジェクト');
      expect(pg.name, 'テストプロジェクト');
      expect(pg.taskIds, isEmpty);
      expect(pg.tags, isEmpty);
    });

    test('Construction with all fields', () {
      final pg = ProjectGroup(
        name: '大祓いの儀',
        taskIds: ['t1', 't2'],
        tags: ['神事', '緊急'],
      );
      expect(pg.name, '大祓いの儀');
      expect(pg.taskIds, ['t1', 't2']);
      expect(pg.tags, ['神事', '緊急']);
    });

    test('Equality', () {
      final a = ProjectGroup(name: 'A', taskIds: ['t1']);
      final b = ProjectGroup(name: 'A', taskIds: ['t1']);
      final c = ProjectGroup(name: 'B');
      expect(a, b);
      expect(a, isNot(c));
    });

    test('fromJson / toJson round trip', () {
      final original = ProjectGroup(
        name: '魔導書翻訳',
        taskIds: ['abc', 'def'],
        tags: ['翻訳', '魔導書'],
      );
      final json = original.toJson();
      final restored = ProjectGroup.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.taskIds, original.taskIds);
      expect(restored.tags, original.tags);
    });

    test('addTask', () {
      final pg = ProjectGroup(name: 'P');
      pg.addTask('new-task');
      expect(pg.taskIds, contains('new-task'));
      // 重複追加は無視
      pg.addTask('new-task');
      expect(pg.taskIds.where((id) => id == 'new-task').length, 1);
    });

    test('removeTask', () {
      final pg = ProjectGroup(name: 'P', taskIds: ['a', 'b', 'c']);
      pg.removeTask('b');
      expect(pg.taskIds, ['a', 'c']);
      // 存在しないIDは無視
      pg.removeTask('nonexistent');
      expect(pg.taskIds, ['a', 'c']);
    });
  });
}
