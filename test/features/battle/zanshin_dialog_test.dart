import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/zanshin_dialog.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// Helper: show ZanshinDialog and settle animations.
Future<void> pumpZanshinDialog(
  WidgetTester tester, {
  required String taskId,
  String taskTitle = 'テスト討伐',
  QuestRank aiDifficulty = QuestRank.B,
  int inputBonusExp = 50,
  VoidCallback? onKaishin,
  VoidCallback? onImashime,
  Player? player,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              ZanshinDialog.show(
                context,
                taskId: taskId,
                taskTitle: taskTitle,
                aiDifficulty: aiDifficulty,
                inputBonusExp: inputBonusExp,
                onKaishin: onKaishin ?? () {},
                onImashime: onImashime ?? () {},
                player: player,
              );
            },
            child: const Text('Show'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Show'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  late String tempDir;
  late ReflectionRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_').path;
    Hive.init(tempDir);
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ReflectionAdapter());
    }
    repository = ReflectionRepository();
  });

  tearDown(() async {
    await repository.clearAll();
    await repository.close();
    await Hive.close();
    if (Directory(tempDir).existsSync()) {
      Directory(tempDir).deleteSync(recursive: true);
    }
  });

  group('ZanshinDialog 会心選択', () {
    testWidgets('会心選択 → sentiment=kaishin で Reflection 保存', (tester) async {
      bool kaishinCalled = false;
      bool imashimeCalled = false;

      final player = Player(currentJob: Job.samurai, wisdomPoints: 0);

      await pumpZanshinDialog(
        tester,
        taskId: 'task-kaishin-1',
        taskTitle: '会心テスト討伐',
        onKaishin: () => kaishinCalled = true,
        onImashime: () => imashimeCalled = true,
        player: player,
      );

      // 「会心」ボタンをタップ
      expect(find.text('会心 — 見事な太刀筋'), findsOneWidget);
      await tester.tap(find.text('会心 — 見事な太刀筋'));
      await tester.pumpAndSettle();

      // コールバック確認
      expect(kaishinCalled, true);
      expect(imashimeCalled, false);

      // Reflection が sentiment='kaishin' で保存されている
      final reflections = await repository.getAll();
      expect(reflections.length, 1);
      expect(reflections.first.sentiment, 'kaishin');
      expect(reflections.first.content, '会心の一撃');

      // WisdomPoints 変化なし
      expect(player.wisdomPoints, 0);
    });

    testWidgets('会心選択では WisdomPoints 変化なし', (tester) async {
      final player = Player(currentJob: Job.samurai, wisdomPoints: 5);

      await pumpZanshinDialog(
        tester,
        taskId: 'task-kaishin-wp',
        player: player,
      );

      await tester.tap(find.text('会心 — 見事な太刀筋'));
      await tester.pumpAndSettle();

      expect(player.wisdomPoints, 5);
    });
  });

  group('ZanshinDialog 戒め選択', () {
    testWidgets('戒め選択 → sentiment=imashime で Reflection 保存（テキストあり）',
        (tester) async {
      bool kaishinCalled = false;
      bool imashimeCalled = false;

      final player = Player(currentJob: Job.samurai, wisdomPoints: 0);

      await pumpZanshinDialog(
        tester,
        taskId: 'task-imashime-1',
        taskTitle: '戒めテスト討伐',
        onKaishin: () => kaishinCalled = true,
        onImashime: () => imashimeCalled = true,
        player: player,
      );

      // 「戒め」ボタンをタップ（入力画面に遷移）
      expect(find.text('戒め — 次に活かす'), findsOneWidget);
      await tester.tap(find.text('戒め — 次に活かす'));
      await tester.pumpAndSettle();

      // テキスト入力フィールドが表示されている
      expect(find.byType(TextField), findsOneWidget);

      // テキストを入力
      await tester.enterText(find.byType(TextField), '準備を怠らぬこと');
      await tester.pumpAndSettle();

      // 戒めを刻むボタンをタップ
      await tester.tap(find.text('戒めを刻む'));
      await tester.pumpAndSettle();

      // コールバック確認
      expect(kaishinCalled, false);
      expect(imashimeCalled, true);

      // Reflection が sentiment='imashime' で保存されている
      final reflections = await repository.getAll();
      expect(reflections.length, 1);
      expect(reflections.first.sentiment, 'imashime');
      expect(reflections.first.content, '準備を怠らぬこと');

      // WisdomPoints +1
      expect(player.wisdomPoints, 1);
    });

    testWidgets('戒め選択 → テキスト空でも保存可能', (tester) async {
      bool imashimeCalled = false;

      final player = Player(currentJob: Job.samurai, wisdomPoints: 0);

      await pumpZanshinDialog(
        tester,
        taskId: 'task-imashime-empty',
        onImashime: () => imashimeCalled = true,
        player: player,
      );

      // 「戒め」ボタンをタップ
      await tester.tap(find.text('戒め — 次に活かす'));
      await tester.pumpAndSettle();

      // テキストを空のまま戒めを刻む
      await tester.tap(find.text('戒めを刻む'));
      await tester.pumpAndSettle();

      expect(imashimeCalled, true);

      // 空テキストで保存されている
      final reflections = await repository.getAll();
      expect(reflections.length, 1);
      expect(reflections.first.sentiment, 'imashime');
      expect(reflections.first.content, '');

      // WisdomPoints +1（空でも加算）
      expect(player.wisdomPoints, 1);
    });

    testWidgets('WisdomPointsが戒め選択後に+1される', (tester) async {
      final player = Player(currentJob: Job.samurai, wisdomPoints: 3);

      await pumpZanshinDialog(
        tester,
        taskId: 'task-imashime-wp',
        player: player,
      );

      await tester.tap(find.text('戒め — 次に活かす'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '次はもっと早く');
      await tester.pumpAndSettle();

      await tester.tap(find.text('戒めを刻む'));
      await tester.pumpAndSettle();

      expect(player.wisdomPoints, 4);
    });
  });

  group('ZanshinDialog UI', () {
    testWidgets('タイトル「⚔️ 残心の刻」が表示される', (tester) async {
      await pumpZanshinDialog(
        tester,
        taskId: 'task-ui-1',
        taskTitle: 'UIテスト',
      );

      expect(find.text('⚔️ 残心の刻'), findsOneWidget);
    });

    testWidgets('クエスト名が表示される', (tester) async {
      await pumpZanshinDialog(
        tester,
        taskId: 'task-ui-2',
        taskTitle: '特別なクエスト名',
      );

      expect(find.textContaining('特別なクエスト名'), findsOneWidget);
    });

    testWidgets('inputBonusExp が表示される', (tester) async {
      await pumpZanshinDialog(
        tester,
        taskId: 'task-ui-3',
        inputBonusExp: 80,
      );

      expect(find.textContaining('+80'), findsOneWidget);
    });
  });
}
