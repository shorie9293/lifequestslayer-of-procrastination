import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/streak_freeze/data/streak_freeze_repository.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_app_keys.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_screen.dart';

class _FakePlayerRepository implements IPlayerRepository {
  _FakePlayerRepository(this._player);

  Player? _player;

  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<Player?> loadPlayer() async => _player;

  @override
  Future<void> savePlayer(Player player) async => _player = player;

  @override
  Future<void> close() async {}
}

final DateTime _now = DateTime(2026, 10, 20, 9);

/// 2日前にログインしていた（1日休んだ）プレイヤーでログイン処理を回し、
/// 切断とお休み券の提案を発生させる。
PlayerViewModel _brokenViewModel() {
  final player = Player(
    streakDays: 12,
    longestStreak: 20,
    lastLoginDate: DateTime(2026, 10, 18, 9),
  );
  final vm = PlayerViewModel(_FakePlayerRepository(player));
  vm.player = player;
  vm.checkAndResetMissions(_now, login: true);
  return vm;
}

PlayerViewModel _stableViewModel() {
  // 連続記録が7日未満＝マイルストーン未到達（券の自動付与が起きない前提）。
  final player = Player(
    streakDays: 5,
    longestStreak: 6,
    lastLoginDate: DateTime(2026, 10, 19, 9),
  );
  final vm = PlayerViewModel(_FakePlayerRepository(player));
  vm.player = player;
  vm.checkAndResetMissions(_now, login: true);
  return vm;
}

Future<void> _pump(
  WidgetTester tester, {
  required PlayerViewModel vm,
  required StreakFreezeRepository repository,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: StreakFreezeScreen(
      repository: repository,
      playerViewModel: vm,
      clock: () => _now,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('残数のラベルを表示する', (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 2));
    await _pump(tester, vm: _stableViewModel(), repository: repo);

    expect(find.byKey(StreakFreezeKeys.screen), findsOneWidget);
    expect(find.text('お休み券 2 / 3 枚'), findsOneWidget);
  });

  testWidgets('切断が無ければ提案は出ない', (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 1));
    await _pump(tester, vm: _stableViewModel(), repository: repo);

    expect(find.byKey(StreakFreezeKeys.noOfferLabel), findsOneWidget);
    expect(find.byKey(StreakFreezeKeys.useButton), findsNothing);
  });

  testWidgets('券が足りなければ使用ボタンを出さず不足を明示する', (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 0));
    await _pump(tester, vm: _brokenViewModel(), repository: repo);

    expect(find.byKey(StreakFreezeKeys.insufficientLabel), findsOneWidget);
    expect(find.byKey(StreakFreezeKeys.useButton), findsNothing);
    expect(find.textContaining('必要 1枚 / 所持 0枚'), findsOneWidget);
  });

  testWidgets('使用すると券が減り連続記録が復元され履歴に残る', (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 1));
    final vm = _brokenViewModel();
    expect(vm.player.streakDays, 1, reason: '前提: 切断されている');
    await _pump(tester, vm: vm, repository: repo);

    expect(find.byKey(StreakFreezeKeys.useButton), findsOneWidget);
    await tester.tap(find.byKey(StreakFreezeKeys.useButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(vm.player.streakDays, 13);
    expect(vm.pendingStreakFreezeOffer, isNull);
    expect(repo.state.tickets, 0);
    expect(repo.state.history.length, 1);
    expect(find.text('お休み券 0 / 3 枚'), findsOneWidget);
    expect(find.byKey(StreakFreezeKeys.historyTile(0)), findsOneWidget);
    expect(find.textContaining('連続 12日を守った'), findsOneWidget);
  });

  testWidgets('到達済みマイルストーンの券が読み込み時に付与される', (tester) async {
    final player = Player(streakDays: 14, longestStreak: 14);
    final vm = PlayerViewModel(_FakePlayerRepository(player));
    vm.player = player;
    final repo = InMemoryStreakFreezeRepository();

    await _pump(tester, vm: vm, repository: repo);

    expect(find.text('お休み券 2 / 3 枚'), findsOneWidget);
    expect(repo.saveCount, 1, reason: '付与を永続化まで到達させる');
    expect(repo.state.grantedMilestones, [7, 14]);
  });

  testWidgets('履歴が無ければ空状態を表示する', (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 1));
    await _pump(tester, vm: _stableViewModel(), repository: repo);

    expect(find.byKey(StreakFreezeKeys.emptyHistory), findsOneWidget);
  });
}
