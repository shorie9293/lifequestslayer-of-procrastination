import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/streak_freeze/data/streak_freeze_repository.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_service.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_app_keys.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_screen.dart';

/// 親探針（合成の不変条件）— 眷属の個別試練では撃たない組み合わせを撃つ。
class _RecordingPlayerRepository implements IPlayerRepository {
  Player? saved;
  int saveCount = 0;

  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<Player?> loadPlayer() async => saved;

  @override
  Future<void> savePlayer(Player player) async {
    saved = player;
    saveCount++;
  }

  @override
  Future<void> close() async {}
}

final DateTime _now = DateTime(2026, 10, 20, 9);

PlayerViewModel _brokenViewModel(_RecordingPlayerRepository repo) {
  final player = Player(
    streakDays: 12,
    longestStreak: 20,
    lastLoginDate: DateTime(2026, 10, 18, 9),
  );
  final vm = PlayerViewModel(repo);
  vm.player = player;
  vm.checkAndResetMissions(_now, login: true);
  return vm;
}

Future<void> _pump(WidgetTester tester, PlayerViewModel vm,
    StreakFreezeRepository repo) async {
  await tester.pumpWidget(MaterialApp(
    home: StreakFreezeScreen(
        repository: repo, playerViewModel: vm, clock: () => _now),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('親探針1: 使用が保存まで到達し、別インスタンスの画面で復元される',
      (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 1));
    final playerRepo = _RecordingPlayerRepository();
    final vm = _brokenViewModel(playerRepo);

    await _pump(tester, vm, repo);
    await tester.tap(find.byKey(StreakFreezeKeys.useButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // state だけでなく永続化に到達したか
    expect(repo.saveCount, greaterThanOrEqualTo(1));
    expect(repo.state.tickets, 0);
    expect(repo.state.history.length, 1);

    // 再入場相当: 新しい画面インスタンスで同じ repo を読む。
    // 復元後の連続13日はマイルストーン(7日)を通過しているため、
    // 未付与だった1枚がこの読み込みで付与される（履歴は消えない）。
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, vm, repo);
    expect(repo.state.history.length, 1);
    expect(repo.state.grantedMilestones, contains(7));
    expect(find.text('お休み券 1 / 3 枚'), findsOneWidget);
    expect(find.byKey(StreakFreezeKeys.historyTile(0)), findsOneWidget);
  });

  testWidgets('親探針2: 券不足なら提案があっても押せず、何も変化しない',
      (tester) async {
    final repo = InMemoryStreakFreezeRepository(
        const StreakFreezeState(tickets: 0));
    final playerRepo = _RecordingPlayerRepository();
    final vm = _brokenViewModel(playerRepo);
    final streakBefore = vm.player.streakDays;

    await _pump(tester, vm, repo);

    expect(find.byKey(StreakFreezeKeys.useButton), findsNothing);
    expect(find.byKey(StreakFreezeKeys.insufficientLabel), findsOneWidget);
    expect(vm.player.streakDays, streakBefore);
    expect(repo.state.history, isEmpty);
    expect(repo.saveCount, 0);
  });

  testWidgets('親探針3: 切断→提案→復元の合成（VMまで貫通する）', (tester) async {
    final playerRepo = _RecordingPlayerRepository();
    final vm = _brokenViewModel(playerRepo);

    // 提案が正しく作られている（1日休み・切断前12日）
    final offer = vm.pendingStreakFreezeOffer;
    expect(offer, isNotNull);
    expect(offer!.previousStreak, 12);
    expect(offer.missedDays, 1);
    expect(offer.missedDateKeys, ['2026-10-19']);

    // 画面を介さずVMを撃つ: 復元・最長・保存・提案消滅
    expect(vm.applyStreakFreeze(_now), isTrue);
    expect(vm.player.streakDays, 13);
    expect(vm.player.longestStreak, 20);
    expect(vm.pendingStreakFreezeOffer, isNull);
    await tester.pump();
    expect(playerRepo.saved?.streakDays, 13, reason: 'リポジトリ保存まで到達する');

    // 提案が無い状態で再度撃っても何も起きない
    expect(vm.applyStreakFreeze(_now), isFalse);
    expect(vm.player.streakDays, 13);
  });

  testWidgets('親探針4: 旧JSON（券のみ）から読んでも付与が二重にならない',
      (tester) async {
    final legacy = StreakFreezeState.fromJson({'tickets': 1});
    final repo = InMemoryStreakFreezeRepository(legacy);
    final player = Player(streakDays: 14, longestStreak: 14);
    final vm = PlayerViewModel(_RecordingPlayerRepository());
    vm.player = player;

    await _pump(tester, vm, repo);
    // 1 + マイルストーン2 = 3（上限）
    expect(repo.state.tickets, 3);
    expect(find.text('お休み券 3 / 3 枚'), findsOneWidget);

    // 再入場しても増えない
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, vm, repo);
    expect(repo.state.tickets, 3);
    final (again, granted) = StreakFreezeService.reconcile(repo.state, 14);
    expect(granted, 0);
    expect(again.tickets, 3);
  });
}
