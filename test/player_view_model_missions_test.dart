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

    test('初回ログインで毎日ボーナス50文 + 月次ボーナス5000文が付与される', () {
      final jan1 = DateTime(2026, 1, 1, 10, 0);
      vm.checkAndResetMissions(jan1, login: true);

      // 毎日50 + 月次5000 = 5050
      expect(vm.pendingLoginBonusAmount, 5050);
      // ストリーク(1日=0文) + 毎日50 + 月次5000 = 5050
      expect(vm.player.coins, 5050);
    });

    test('同日のログインではログインボーナスは付与されない', () {
      final jan1 = DateTime(2026, 1, 1, 10, 0);
      vm.checkAndResetMissions(jan1, login: true);
      vm.clearPendingLoginBonus();

      // 同日に再ログイン
      vm.checkAndResetMissions(DateTime(2026, 1, 1, 15, 0), login: true);
      // 同日の再起動はストリーク・毎日・月次ともスキップ
      expect(vm.pendingLoginBonusAmount, isNull);
      expect(vm.player.coins, 5050);
    });

    test('翌日（同月）のログインでは毎日ボーナス50文のみ付与される', () {
      vm.checkAndResetMissions(DateTime(2026, 1, 1, 10, 0), login: true);
      vm.clearPendingLoginBonus();

      // 1月2日 — 毎日ボーナス50文のみ（月次は月初のみ）
      vm.checkAndResetMissions(DateTime(2026, 1, 2, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 50);
      // 1月1日: streak(1日=0) + 毎日50 + 月次5000 = 5050
      // 1月2日: streak(2日=100) + 毎日50 = 150
      // 合計: 5200
      expect(vm.player.coins, 5200);
    });

    test('翌月1日のログインで毎日ボーナス50文 + 月次ボーナス5000文が再付与される', () {
      vm.checkAndResetMissions(DateTime(2026, 1, 30, 10, 0), login: true);
      vm.clearPendingLoginBonus();
      // 1月30日: streak(1日=0) + 毎日50 + 月次5000 = 5050
      expect(vm.player.coins, 5050);

      // 2月1日 — 月が変わったので毎日+月次両方付与
      vm.checkAndResetMissions(DateTime(2026, 2, 1, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 5050);
      // 1月30日: 5050文
      // 2月1日: streak切れ(リセット→1日=0) + 毎日50 + 月次5000 = 5050
      // 合計: 10100文
      expect(vm.player.coins, 10100);
    });

    test('月末→翌月の連続ログインでも正しく付与される（回帰試験）', () {
      // 1月30日にログイン（初回）
      vm.checkAndResetMissions(DateTime(2026, 1, 30, 10, 0), login: true);
      vm.clearPendingLoginBonus();
      // streak(1日=0) + 毎日50 + 月次5000 = 5050

      // 1月31日にログイン（同月なので毎日ボーナス50文のみ）
      vm.checkAndResetMissions(DateTime(2026, 1, 31, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 50);
      vm.clearPendingLoginBonus();
      // streak(2日=100) + 毎日50 = +150 → 5050 + 150 = 5200

      // 2月1日にログイン（月が変わったので毎日+月次）
      vm.checkAndResetMissions(DateTime(2026, 2, 1, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 5050);
      // streak(3日=200) + 毎日50 + 月次5000 = +5250 → 5200 + 5250 = 10450
      expect(vm.player.coins, 10450);

      // 2月2日 — 同月なので毎日ボーナス50文のみ
      vm.clearPendingLoginBonus();
      vm.checkAndResetMissions(DateTime(2026, 2, 2, 10, 0), login: true);
      expect(vm.pendingLoginBonusAmount, 50);
      // streak(4日=0文) + 毎日50 = +50 → 10450 + 50 = 10500
      expect(vm.player.coins, 10500);
    });

    test('login:false の呼び出しではボーナスは付与されない', () {
      vm.checkAndResetMissions(DateTime(2026, 1, 1, 10, 0), login: false);
      expect(vm.pendingLoginBonusAmount, isNull);
      expect(vm.player.coins, 0);
    });
  });
}
