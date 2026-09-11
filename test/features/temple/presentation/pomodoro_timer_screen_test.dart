import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
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

Widget host(PlayerViewModel vm, {Widget? child}) {
  return ChangeNotifierProvider<PlayerViewModel>.value(
    value: vm,
    // MaterialApp の外側に置くことで push された route からも参照できる
    // （本番 main.dart と同じ配置）。
    child: MaterialApp(home: child ?? const PomodoroTimerScreen()),
  );
}

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
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();

      expect(vm.player.pomodoroStartTime, isNotNull);
      expect(vm.isPomodoroActive, isTrue);
      expect(find.text('一時停止'), findsOneWidget);

      await tester.pump(const Duration(minutes: 1));
      expect(timeText(tester), '24:00');

      // 後始末（pending timer を残さない）
      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
    });

    testWidgets('一時停止でセッション区間が閉じる', (tester) async {
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(vm.player.pomodoroStartTime, isNotNull);

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      expect(vm.player.pomodoroStartTime, isNull);
      expect(find.text('開始'), findsOneWidget);
    });

    testWidgets('リセットで初期状態に戻りセッションが閉じる', (tester) async {
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      await tester.pumpWidget(host(vm));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump(const Duration(minutes: 3));
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
      final vm = PlayerViewModel(_MockPlayerRepo());
      await vm.load();
      // 1回のtickで25分進む設定にして満了させる
      await tester.pumpWidget(host(
        vm,
        child: const PomodoroTimerScreen(tickInterval: Duration(minutes: 25)),
      ));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
      await tester.pump(const Duration(minutes: 25));

      expect(timeText(tester), '05:00');
      expect(find.text('小休止'), findsOneWidget);
      expect(find.textContaining('完了セッション: 1回'), findsOneWidget);
      // 休憩中は勤行EXPボーナス区間が閉じている
      expect(vm.player.pomodoroStartTime, isNull);

      await tester.tap(find.byKey(AppKeys.pomodoroStartPause));
      await tester.pump();
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
