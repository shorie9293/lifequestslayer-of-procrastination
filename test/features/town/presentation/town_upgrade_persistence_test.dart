import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/features/town/domain/building.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';

class _FakePlayerRepo implements IPlayerRepository {
  @override bool get loadFailedDueToCorruption => false;
  final Player _p;
  _FakePlayerRepo(this._p);
  @override Future<Player?> loadPlayer() async => _p;
  @override Future<void> savePlayer(Player p) async {}
  @override Future<void> close() async {}
}

void main() {
  late Box<dynamic> box;

  setUp(() async {
    Hive.init('test/hive_testing_path');
    box = await Hive.openBox<dynamic>('townBox_tap_test');
    await box.clear();
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets('UP button tap → save → load → inn level persists', (tester) async {
    final player = Player(coins: 1000, jobLevels: {Job.adventurer: 1});
    final playerVM = PlayerViewModel(_FakePlayerRepo(player));
    await playerVM.load();

    final townVM = TownViewModel();
    townVM.boxForTest = box;
    townVM.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
          ChangeNotifierProvider<ShopViewModel>.value(value: ShopViewModel(playerVM)),
          ChangeNotifierProvider<TownViewModel>.value(value: townVM),
        ],
        child: const MaterialApp(home: TownScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial: inn Lv1, shows UP 100文
    expect(townVM.buildings[Building.inn]!.level, equals(1));

    // Tap UP button
    final upBtn = find.text('UP 100文');
    expect(upBtn, findsOneWidget, reason: 'Should find UP 100文 button');
    await tester.tap(upBtn);
    await tester.pumpAndSettle();

    // After tap: inn should be Lv2
    expect(townVM.buildings[Building.inn]!.level, equals(2),
        reason: 'Inn should be level 2 after tapping UP');

    // Manually call save (simulating the onUpgrade callback)
    await townVM.save();

    // Simulate app restart: new VM loads from same box
    final restoredVM = TownViewModel();
    restoredVM.boxForTest = box;
    await restoredVM.load();
    restoredVM.initialize();

    expect(restoredVM.buildings[Building.inn]!.level, equals(2),
        reason: 'CRITICAL: Inn level MUST persist after save+load cycle');
  });
}
