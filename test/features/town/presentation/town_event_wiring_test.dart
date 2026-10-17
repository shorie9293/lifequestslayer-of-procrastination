import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/data/random_event_store.dart';
import 'package:rpg_todo/features/town/domain/random_event.dart';
import 'package:rpg_todo/features/town/domain/random_event_service.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';

class _MockPlayerRepository implements IPlayerRepository {
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<Player?> loadPlayer() async => _player;

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  Future<void> close() async {}
}

const _merchant = RandomEvent(
  type: EventType.merchant,
  title: '旅の商人',
  description: '特別な品を仕入れてきたぞ',
  emoji: '🏪',
  reward: {'xp': 5, 'gems': 3},
);

void main() {
  late Directory tempDir;
  late PlayerViewModel playerVM;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
    final player = Player(jobLevels: {Job.adventurer: 50}, gems: 10);
    playerVM = PlayerViewModel(_MockPlayerRepository(player));
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<ShopViewModel>(create: (_) => ShopViewModel(playerVM)),
          ChangeNotifierProvider<TownViewModel>(create: (_) => TownViewModel()),
          ChangeNotifierProvider<SettingsViewModel>.value(
            value: SettingsViewModel(SettingsRepository()),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('町画面へのランダムイベント配線', () {
    testWidgets('eventChecker がイベントを返すと町画面に overlay が出る', (tester) async {
      await pumpScreen(
        tester,
        TownScreen(eventChecker: () async => _merchant),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.townScreen), findsOneWidget);
      expect(find.byKey(AppKeys.townEventOverlay), findsOneWidget);
      expect(find.text('旅の商人'), findsOneWidget);
    });

    testWidgets('eventChecker が null を返せば overlay は出ない', (tester) async {
      await pumpScreen(
        tester,
        TownScreen(eventChecker: () async => null),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.townScreen), findsOneWidget);
      expect(find.byKey(AppKeys.townEventOverlay), findsNothing);
    });

    testWidgets('報酬が Player へ実際に付与される（画面→イベント→報酬の合成）', (tester) async {
      final beforeGems = playerVM.player.gems;
      final beforeExp = playerVM.player.currentExp;

      await pumpScreen(
        tester,
        TownScreen(eventChecker: () async => _merchant),
      );
      await tester.pumpAndSettle();

      expect(playerVM.player.gems, beforeGems + 3);
      expect(playerVM.player.currentExp, beforeExp + 5);
    });

    testWidgets('閉じると overlay が消える（町画面はそのまま）', (tester) async {
      await pumpScreen(
        tester,
        TownScreen(eventChecker: () async => _merchant),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.townEventClose));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.townEventOverlay), findsNothing);
      expect(find.byKey(AppKeys.townScreen), findsOneWidget);
    });
  });

  group('親探針: サービス→ストア→画面の合成不変条件', () {
    testWidgets('1日3回の上限が画面の再入場をまたいで効く', (tester) async {
      final store = InMemoryRandomEventStore();
      final service = RandomEventService(
        random: _FixedRandom(0.0),
        store: store,
        clock: () => DateTime(2026, 10, 17, 12),
      );

      var shown = 0;
      for (var visit = 0; visit < 4; visit++) {
        // 町画面へ入り直すたびに新しい State を作る
        await pumpScreen(
          tester,
          TownScreen(
            key: ValueKey('town_visit_$visit'),
            eventChecker: service.checkForEvent,
          ),
        );
        await tester.pumpAndSettle();
        if (find.byKey(AppKeys.townEventOverlay).evaluate().isNotEmpty) {
          shown++;
          await tester.tap(find.byKey(AppKeys.townEventClose));
          await tester.pumpAndSettle();
        }
      }

      expect(shown, 3, reason: '4回目の入場では日次上限に達して抽選されない');
      expect(await service.dailyCount(), 3);
    });

    testWidgets('日付が変われば再び3回まで出会える', (tester) async {
      final store = InMemoryRandomEventStore();
      var now = DateTime(2026, 10, 17, 23, 50);
      final service = RandomEventService(
        random: _FixedRandom(0.0),
        store: store,
        clock: () => now,
      );

      for (var i = 0; i < 3; i++) {
        expect(await service.checkForEvent(), isNotNull);
      }
      expect(await service.checkForEvent(), isNull);

      now = DateTime(2026, 10, 18, 0, 10);
      expect(await service.checkForEvent(), isNotNull);
    });
  });
}

/// 常に確率を通過する Random。
class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
