import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/pomodoro_state_store.dart';
import 'package:rpg_todo/features/shared/domain/pomodoro_runtime.dart';
import 'package:rpg_todo/features/temple/presentation/pomodoro_timer_screen.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player;

  _MockPlayerRepo([Player? player]) : _player = player ?? Player();

  @override
  Future<Player> loadPlayer() async => _player;

  @override
  Future<void> savePlayer(Player p) async => _player = p;

  @override
  Future<void> close() async {}
}

/// 壊れた保存値（JSONとして不正）を返すストア。
class _RawJsonStore implements PomodoroStateStore {
  _RawJsonStore(this.raw);

  final String raw;
  int saveCount = 0;

  @override
  Future<PomodoroSnapshot?> load() async => PomodoroSnapshot.tryFromJson(raw);

  @override
  Future<void> save(PomodoroSnapshot snapshot) async => saveCount++;

  @override
  Future<void> clear() async {}
}

Widget host(PlayerViewModel vm, {Widget? child}) {
  return ChangeNotifierProvider<PlayerViewModel>.value(
    value: vm,
    // MaterialApp の外側に置くことで push された route からも参照できる
    // （本番 main.dart と同じ配置）。
    child: MaterialApp(home: child ?? const PomodoroTimerScreen()),
  );
}

/// 偽時計とストアを注入したタイマー画面。
PomodoroTimerScreen timerScreen({
  required DateTime Function() now,
  PomodoroStateStore? store,
}) =>
    PomodoroTimerScreen(now: now, store: store);

String timeText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(AppKeys.pomodoroTime)).data!;

void main() {
  group('PomodoroTimerScreen — 表示', () {
    testWidgets('初期状態は集中25:00・開始ボタン', (tester) async {
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();

      await tester.pumpWidget(host(vm));
      await tester.pump();

      expect(find.byKey(AppKeys.pomodoroScreen), findsOneWidget);
      expect(timeText(tester), '25:00');
      expect(find.byKey(AppKeys.pomodoroPhaseLabel), findsOneWidget);
      expect(find.text('開始'), findsOneWidget);
      expect(find.textContaining('完了セッション: 0回'), findsOneWidget);
    });

    testWidgets('Playerの設定値が反映される', (tester) async {
      final vm = PlayerViewModel(_MockPlayerRepo(Player(
        pomodoroMinutes: 50,
        pomodoroShortBreakMinutes: 10,
        pomodoroLongBreakMinutes: 30,
        pomodorosBeforeLongBreak: 2,
      )));
      await vm.load();

      await tester.pumpWidget(host(vm));
      await tester.pump();

      expect(timeText(tester), '50:00');
      expect(find.textContaining('集中50分'), findsOneWidget);
      expect(find.textContaining('長休止30分'), findsOneWidget);
    });

    testWidgets('集中の型スキルの解放状態を表示する', (tester) async {
      final unlocked = PlayerViewModel(_MockPlayerRepo(Player(
        currentJob: Job.samurai,
        jobLevels: {Job.adventurer: 1, Job.samurai: 10},
      )));
      await unlocked.load();
      await tester.pumpWidget(host(unlocked));
      await tester.pump();
      expect(find.textContaining('解放済み'), findsOneWidget);

      final locked = PlayerViewModel(_MockPlayerRepo());
      await locked.load();
      await tester.pumpWidget(host(locked));
      await tester.pump();
      expect(find.textContaining('未解放'), findsOneWidget);
    });
  });

  group('PomodoroTimerScreen — 計時と勤行連動', () {
    testWidgets('開始でセッションが開き、1分経過で24:00になる', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm, child: timerScreen(now: nowFn)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      expect(vm.player.pomodoroStartTime, isNotNull);
      expect(vm.isPomodoroActive, isTrue);
      expect(find.text('一時停止'), findsOneWidget);

      // 実時間（偽時計）を1分進めてから描画を進める。
      fake = fake.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), '24:00');

      // 後始末（pending timer を残さない）
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
    });

    testWidgets('一時停止でセッション区間が閉じる', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm, child: timerScreen(now: nowFn)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      fake = fake.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(vm.player.pomodoroStartTime, isNotNull);

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      expect(vm.player.pomodoroStartTime, isNull);
      expect(find.text('開始'), findsOneWidget);
    });

    testWidgets('リセットで初期状態に戻りセッションが閉じる', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm, child: timerScreen(now: nowFn)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      fake = fake.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(AppKeys.pomodoroReset));
      await tester.pump();

      expect(timeText(tester), '25:00');
      expect(vm.player.pomodoroStartTime, isNull);
      expect(find.textContaining('完了セッション: 0回'), findsOneWidget);
    });

    testWidgets('次のフェーズへ で小休止へ移行（セッション数は増えない）', (tester) async {
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroSkip));
      await tester.pump();

      expect(timeText(tester), '05:00');
      expect(find.text('小休止'), findsOneWidget);
      expect(find.textContaining('完了セッション: 0回'), findsOneWidget);
    });

    testWidgets('集中フェーズを走り切るとセッション数が増え小休止になる', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm, child: timerScreen(now: nowFn)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      // tick の積算ではなく実時間差で満了させる。
      fake = fake.add(const Duration(minutes: 25));
      await tester.pump(const Duration(seconds: 1));

      expect(timeText(tester), '05:00');
      expect(find.text('小休止'), findsOneWidget);
      expect(find.textContaining('完了セッション: 1回'), findsOneWidget);
      // 休憩中は勤行EXPボーナス区間が閉じている
      expect(vm.player.pomodoroStartTime, isNull);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('PomodoroTimerScreen — 実時間差と永続化', () {
    testWidgets('実時間差で減る（tick の積算に依存しない）', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      fake = fake.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), '24:00');

      // 描画のきっかけが1回だけでも、実時間差なら正しく積み上がる。
      fake = fake.add(const Duration(minutes: 4, seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), '19:30');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('再入場（同じ store・新しい画面）で残り時間が実時間差で復元される', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();

      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      fake = fake.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), '20:00');

      // 画面を作り直す（＝離脱して再入場）。
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.pump();

      expect(timeText(tester), '20:00');
      expect(find.text('一時停止'), findsOneWidget);

      // さらに実時間が進めば減り続ける。
      fake = fake.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), '19:00');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('再起動相当（store を共有して完全に作り直す）で走行状態と完了数が復元される', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();

      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      fake = fake.add(const Duration(minutes: 25));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('完了セッション: 1回'), findsOneWidget);

      // アプリ再起動に相当（別のウィジェットインスタンス・同じストア）。
      final vm2 = PlayerViewModel(_MockPlayerRepo());
      await vm2.load();
      await tester
          .pumpWidget(host(vm2, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.pump();

      expect(find.text('小休止'), findsOneWidget);
      expect(find.textContaining('完了セッション: 1回'), findsOneWidget);
      expect(find.text('一時停止'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('一時停止→再入場で残量が凍結されている（実時間を進めても減らない）', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();

      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      fake = fake.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      expect(timeText(tester), '23:00');

      fake = fake.add(const Duration(minutes: 10));
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.pump();

      expect(timeText(tester), '23:00');
      expect(find.text('開始'), findsOneWidget);
    });

    testWidgets('25分経過で完了+1・小休止へ・Player区間が閉じる', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      expect(vm.isPomodoroActive, isTrue);

      fake = fake.add(const Duration(minutes: 25));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('小休止'), findsOneWidget);
      expect(find.textContaining('完了セッション: 1回'), findsOneWidget);
      expect(vm.player.pomodoroStartTime, isNull);
      expect(timeText(tester), '05:00');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('巻き戻り時計（過去へ戻る）でも落ちない', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      fake = fake.subtract(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.pomodoroScreen), findsOneWidget);
      // 経過は負にならず「開始直後（満タン）」として扱われる。
      expect(timeText(tester), '25:00');
      expect(find.text('一時停止'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('アプリ復帰（resumed）で実時間差ぶん進む', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      // バックグラウンド中は tick が止まる想定で、実時間だけを進める。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      fake = fake.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(timeText(tester), '15:00');
      expect(find.text('一時停止'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('破損保存値でも25:00で起動し落ちない', (tester) async {
      final store = _RawJsonStore('{"phase": "focus", "isRunning": ');
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(
          host(vm, child: timerScreen(now: DateTime.now, store: store)));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(timeText(tester), '25:00');
      expect(find.text('開始'), findsOneWidget);
      expect(store.saveCount, 0);
    });

    testWidgets('リセットで保存が消え、再入場しても25:00', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      fake = fake.add(const Duration(minutes: 7));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(AppKeys.pomodoroReset));
      await tester.pump();
      await tester.pump();

      expect(await store.load(), isNull);

      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.pump();
      expect(timeText(tester), '25:00');
    });

    testWidgets('スキップも保存され、再入場で小休止が復元される', (tester) async {
      var fake = DateTime(2026, 1, 1, 9, 0);
      DateTime nowFn() => fake;
      final store = InMemoryPomodoroStateStore();
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroSkip));
      await tester.pump();
      await tester.pump();

      await tester
          .pumpWidget(host(vm, child: timerScreen(now: nowFn, store: store)));
      await tester.pump();
      await tester.pump();

      expect(find.text('小休止'), findsOneWidget);
      expect(timeText(tester), '05:00');
    });
  });

  group('寺院からの導線', () {
    testWidgets('寺院AppBarの集中の型ボタンでタイマー画面が開く', (tester) async {
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm, child: const TempleScreen()));
      await tester.pump();

      expect(find.byKey(AppKeys.pomodoroEntry), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.pomodoroEntry));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.pomodoroScreen), findsOneWidget);
      expect(timeText(tester), '25:00');
    });
  });
}
