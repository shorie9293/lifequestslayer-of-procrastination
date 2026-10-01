// PlayerViewModel のプロジェクト編集メソッドの試練
//
// 対象: addProject / renameProject / removeProject / assignTaskToProject /
//       unassignTaskFromProject（lib/features/player/viewmodels/player_view_model.dart）

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

void main() {
  late _MockPlayerRepo repo;
  late PlayerViewModel vm;

  setUp(() {
    repo = _MockPlayerRepo();
    vm = PlayerViewModel(repo);
  });

  group('addProject', () {
    test('新規プロジェクトが projects に追加される', () {
      vm.addProject('計画A', 100);

      expect(vm.player.projects, hasLength(1));
      expect(vm.player.projects.first.name, '計画A');
      expect(vm.player.projects.first.bonusExp, 100);
      expect(vm.player.projects.first.taskIds, isEmpty);
    });
  });

  group('renameProject', () {
    test('名前と bonusExp を更新する', () {
      vm.addProject('旧名', 50);

      vm.renameProject('旧名', '新名', bonusExp: 200);

      expect(vm.player.projects.single.name, '新名');
      expect(vm.player.projects.single.bonusExp, 200);
    });

    test('bonusExp 省略時は既存値を保持する', () {
      vm.addProject('旧名', 50);

      vm.renameProject('旧名', '新名');

      expect(vm.player.projects.single.bonusExp, 50);
    });

    test('taskProjects の参照も新名に張り替わる', () {
      vm.addProject('旧名', 50);
      vm.assignTaskToProject('t1', '旧名');

      vm.renameProject('旧名', '新名');

      expect(vm.player.taskProjects['t1'], '新名');
    });
  });

  group('removeProject', () {
    test('プロジェクトが削除される', () {
      vm.addProject('P', 10);

      vm.removeProject('P');

      expect(vm.player.projects, isEmpty);
    });

    test('所属タスクの taskProjects も掃除される', () {
      vm.addProject('P', 10);
      vm.assignTaskToProject('t1', 'P');
      vm.addProject('Q', 10);
      vm.assignTaskToProject('t2', 'Q');

      vm.removeProject('P');

      expect(vm.player.taskProjects.containsKey('t1'), isFalse);
      expect(vm.player.taskProjects['t2'], 'Q'); // 他プロジェクトは無傷
    });
  });

  group('assignTaskToProject / unassignTaskFromProject', () {
    test('assign で group.taskIds と taskProjects の両方に登録される', () {
      vm.addProject('P', 10);

      vm.assignTaskToProject('t1', 'P');

      expect(vm.player.projects.single.taskIds, ['t1']);
      expect(vm.player.taskProjects['t1'], 'P');
    });

    test('assign は重複登録しない', () {
      vm.addProject('P', 10);

      vm.assignTaskToProject('t1', 'P');
      vm.assignTaskToProject('t1', 'P');

      expect(vm.player.projects.single.taskIds, ['t1']);
    });

    test('unassign で group.taskIds と taskProjects の両方から外れる', () {
      vm.addProject('P', 10);
      vm.assignTaskToProject('t1', 'P');

      vm.unassignTaskFromProject('t1');

      expect(vm.player.projects.single.taskIds, isEmpty);
      expect(vm.player.taskProjects.containsKey('t1'), isFalse);
    });

    test('存在しないプロジェクトへの assign は何もしない', () {
      vm.assignTaskToProject('t1', '無い');

      expect(vm.player.projects, isEmpty);
      expect(vm.player.taskProjects.containsKey('t1'), isFalse);
    });
  });
}