// 寺院画面の「クエストをCSVで書き出す」導線の試練。
//
// AppBar アイコンは増やさず、既存のバックアップ節にボタンを1つ追加する。
// 既存のバックアップ/復元ボタンは健在であること。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
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

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

Future<Widget> _createScreen() async {
  final playerVM = PlayerViewModel(_MockPlayerRepo());
  await playerVM.load();
  final taskVM = TaskViewModel(_FakeTaskRepository(), playerVM);
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
      ],
      child: const TempleScreen(),
    ),
  );
}

Future<void> _reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  group('TempleScreen — クエストCSV導線', () {
    testWidgets('CSV書き出しボタンが表示され、タップ可能（onPressed 非null）',
        (tester) async {
      await tester.pumpWidget(await _createScreen());
      await _reveal(tester, AppKeys.templeCsvExportButton);

      final finder = find.byKey(AppKeys.templeCsvExportButton);
      expect(finder, findsOneWidget);
      expect(find.text('クエストをCSVで書き出す'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(finder);
      expect(button.onPressed, isNotNull);
      expect(tester.getSize(finder).width, greaterThan(0));
    });

    testWidgets('既存のバックアップ/復元ボタンが健在（温存）', (tester) async {
      await tester.pumpWidget(await _createScreen());
      await _reveal(tester, AppKeys.templeCsvExportButton);

      expect(find.byKey(AppKeys.templeBackupButton), findsOneWidget);
      expect(find.byKey(AppKeys.templeRestoreButton), findsOneWidget);
      expect(find.text('データバックアップ'), findsOneWidget);
      expect(find.text('データ復元'), findsOneWidget);
    });

    testWidgets('タップしても例外で落ちない（保存/共有層は握り潰して通知）',
        (tester) async {
      await tester.pumpWidget(await _createScreen());
      await _reveal(tester, AppKeys.templeCsvExportButton);

      await tester.tap(find.byKey(AppKeys.templeCsvExportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
