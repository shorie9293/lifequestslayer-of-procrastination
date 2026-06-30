import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';

/// モックリポジトリ — 何もしない
class MockPlayerRepository implements IPlayerRepository {
  @override
  Future<Player?> loadPlayer() async => null;

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<void> close() async {}
}

void main() {
  group('PlayerViewModel.checkAndResetMissions', () {
    late PlayerViewModel vm;

    setUp(() {
      vm = PlayerViewModel(MockPlayerRepository());
    });

    test('初回ログインでログインボーナス50文が付与される', () {
      final jan1 = DateTime(2026, 1, 1, 10, 0);
      vm.checkAndResetMissions(jan1, login: true);

      expect(vm.pendingLoginBonusAmount, 50);
      // ストリーク(1日=0文) + 月次ボーナス(50文)
      expect(vm.player.coins, 50);
    });

    test('同日のログインではログインボーナスは付与されない', () {
      final jan1 = DateTime(2026, 1, 1, 10, 0);
      vm.checkAndResetMissions(jan1, login: true);
      vm.clearPendingLoginBonus();

      // 同日に再ログイン
      vm.checkAndResetMissions(DateTime(2026, 1, 1, 15, 0), login: true);
      // 同日の再起動はストリーク・月次ボーナスともスキップ
      expect(vm.pendingLoginBonusAmount, isNull);
      expect(vm.player.coins, 50);
    });

    test('翌日（同月）のログインではログインボーナスは付与されない（月1回制限）', () {
      vm.checkAndResetMissions(DateTime(2026, 1, 1, 10, 0), login: true);
      vm.clearPendingLoginBonus();

      // 1月2日 — デイリーミッションはリセット、ストリーク報酬は出るが、月次ボーナスは再付与されない
      vm.checkAndResetMissions(DateTime(2026, 1, 2, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, isNull);
      // 1月1日: ストリーク(1日=0文) + 月次(50文) = 50
      // 1月2日: ストリーク(2日=100文)のみ = 150
      expect(vm.player.coins, 150);
    });

    test('翌月1日のログインでログインボーナスが再付与される', () {
      vm.checkAndResetMissions(DateTime(2026, 1, 30, 10, 0), login: true);
      vm.clearPendingLoginBonus();
      // 1月30日: 初回ストリーク(1日=0文) + 月次(50文) = 50
      expect(vm.player.coins, 50);

      // 2月1日 — 月が変わったので月次ボーナス再付与
      vm.checkAndResetMissions(DateTime(2026, 2, 1, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 50);
      // 1月30日: 50文
      // 2月1日: ストリーク切れ(リセット→1日=0文) + 月次(50文) = 50
      // 合計: 100文
      expect(vm.player.coins, 100);
    });

    test('月末30日→翌月1日の連続ログインで月次ボーナスは二重付与されない（回帰試験）', () {
      // 1月30日にログイン（初回）
      vm.checkAndResetMissions(DateTime(2026, 1, 30, 10, 0), login: true);
      vm.clearPendingLoginBonus();
      // ストリーク(1日=0文) + 月次(50文) = 50

      // 1月31日にログイン（同月なので月次ボーナスなし）
      vm.checkAndResetMissions(DateTime(2026, 1, 31, 10, 0), login: true);
      vm.clearPendingLoginBonus();
      expect(vm.pendingLoginBonusAmount, isNull);
      // ストリーク(2日=100文) = +100 → 150

      // 2月1日にログイン（月が変わったので1回のみ付与）
      vm.checkAndResetMissions(DateTime(2026, 2, 1, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 50);
      // ストリーク(3日=200文) + 月次(50文) = +250 → 400
      expect(vm.player.coins, 400);

      // 2月2日 — 同月なので月次ボーナスなし
      vm.clearPendingLoginBonus();
      vm.checkAndResetMissions(DateTime(2026, 2, 2, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, isNull);
    });

    test('login:false の呼び出しでは月次ボーナスは付与されない', () {
      vm.checkAndResetMissions(DateTime(2026, 1, 1, 10, 0), login: false);
      expect(vm.pendingLoginBonusAmount, isNull);
      expect(vm.player.coins, 0);
    });
  });
}
