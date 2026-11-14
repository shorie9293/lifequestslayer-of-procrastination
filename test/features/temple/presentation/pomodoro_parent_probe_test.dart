import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/pomodoro_state_store.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_runtime.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_timer.dart';
import 'package:rpg_todo/features/temple/presentation/pomodoro_timer_screen.dart';

/// 親探針（イシコリドメ）— 子の個別試練では撃てない合成の不変条件を固定する。
/// 1) 離脱→再入場で残り時間が実時間差で進む（25:00に戻らない）
/// 2) 再起動相当（StateもTimerも新規）でも走行状態と完了数が復元される
/// 3) 表示とEXPボーナスが同一の真実源（集中満了で両方が同時に切り替わる）
/// 4) 一時停止の残量は実時間が経っても凍結されたまま
/// 5) 巻き戻り時計・破損保存値でも落ちない
class _ProbePlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player;

  _ProbePlayerRepo([Player? player]) : _player = player ?? Player();

  @override
  Future<Player> loadPlayer() async => _player;

  @override
  Future<void> savePlayer(Player p) async => _player = p;

  @override
  Future<void> close() async {}
}

Widget _host(PlayerViewModel vm, Widget child) {
  return ChangeNotifierProvider<PlayerViewModel>.value(
    value: vm,
    child: MaterialApp(home: child),
  );
}

String _timeText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(AppKeys.pomodoroTime)).data!;

void main() {
  group('親探針 — 実時間差の計時と永続化の合成', () {
    testWidgets('P1 離脱→再入場で残り時間が実時間差で進む（25:00に戻らない）',
        (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_ProbePlayerRepo());
      await vm.load();

      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      expect(_timeText(tester), '25:00');

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      expect(vm.isPomodoroActive, isTrue);

      // 画面を離れる（Timer は dispose で止まる＝バックグラウンド相当）
      await tester.pumpWidget(const SizedBox());
      fake = fake.add(const Duration(minutes: 27));

      // 再入場（新しい State）
      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.pump();

      // 27分 = 集中25分満了 + 小休止2分経過 → 03:00 / 小休止 / 完了1回
      expect(_timeText(tester), '03:00');
      expect(find.text('小休止'), findsOneWidget);
      expect(find.textContaining('完了セッション: 1回'), findsOneWidget);

      // 後始末
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P2 再起動相当（State・Timerとも新規）でも走行状態が復元される',
        (tester) async {
      var fake = DateTime(2026, 2, 1, 7, 0);
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_ProbePlayerRepo());
      await vm.load();

      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      fake = fake.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(_timeText(tester), '15:00');

      // 完全に破棄してから作り直す（アプリ再起動相当・同じ保存先）
      await tester.pumpWidget(const SizedBox());
      final vm2 = PlayerViewModel(_ProbePlayerRepo());
      await vm2.load();
      await tester.pumpWidget(_host(
        vm2,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.pump();

      expect(_timeText(tester), '15:00');
      expect(find.text('一時停止'), findsOneWidget);
      // 再起動後もEXPボーナス区間が開いている（実時間差で25分以内）
      expect(vm2.isPomodoroActive, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P3 表示とEXPボーナスが同一の真実源（集中満了で同時に切り替わる）',
        (tester) async {
      var fake = DateTime(2026, 3, 1, 10, 0);
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_ProbePlayerRepo());
      await vm.load();

      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      // 24分経過: 表示は集中のまま・EXPボーナスも有効
      fake = fake.add(const Duration(minutes: 24));
      await tester.pump(const Duration(seconds: 1));
      expect(_timeText(tester), '01:00');
      expect(find.text('集中'), findsOneWidget);
      expect(vm.isPomodoroActive, isTrue);

      // さらに2分（合計26分）: 表示は小休止・EXPボーナスは閉じる
      fake = fake.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('小休止'), findsOneWidget);
      expect(vm.isPomodoroActive, isFalse);
      expect(vm.player.pomodoroStartTime, isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P4 一時停止の残量は実時間が経っても凍結される', (tester) async {
      var fake = DateTime(2026, 4, 1, 12, 0);
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_ProbePlayerRepo());
      await vm.load();

      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      fake = fake.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(_timeText(tester), '15:00');

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      expect(find.text('開始'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      fake = fake.add(const Duration(hours: 3));

      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.pump();

      expect(_timeText(tester), '15:00');
      expect(find.text('開始'), findsOneWidget);
      expect(vm.isPomodoroActive, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P5 巻き戻り時計・破損保存値でも落ちない', (tester) async {
      final fake = DateTime(2026, 5, 1, 9, 0);
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_ProbePlayerRepo());
      await vm.load();

      // 未来の開始時刻（時計巻き戻り）を持つ走行状態
      await store.save(PomodoroSnapshot(
        phase: PomodoroPhase.focus,
        phaseStartedAt: fake.add(const Duration(hours: 5)),
        pausedRemaining: const Duration(minutes: 25),
        completedFocusSessions: 0,
        isRunning: true,
      ));

      await tester.pumpWidget(_host(
        vm,
        PomodoroTimerScreen(now: () => fake, store: store),
      ));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.pomodoroScreen), findsOneWidget);
      // 巻き戻りは満タンにクランプ（負の残り時間を表示しない）
      expect(_timeText(tester), '25:00');

      await tester.pumpWidget(const SizedBox());
    });
  });
}
