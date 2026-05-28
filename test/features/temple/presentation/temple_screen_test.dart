import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

class _MockPlayerRepo implements IPlayerRepository {
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

Widget createTempleScreen(PlayerViewModel vm) {
  return MaterialApp(
    home: ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: const TempleScreen(),
    ),
  );
}

void main() {
  late PlayerViewModel vm;
  late _MockPlayerRepo repo;

  setUp(() {
    repo = _MockPlayerRepo();
    vm = PlayerViewModel(repo);
  });

  group('TempleScreen', () {
    testWidgets('renders scaffold with key', (tester) async {
      await vm.load();
      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.templeScreen), findsOneWidget);
    });

    testWidgets('skill slot section renders', (tester) async {
      await vm.load();
      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down to see the skill slot section
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.templeSkillSlotSection), findsOneWidget);
    });

    testWidgets('current job skills section renders', (tester) async {
      await vm.load();
      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Adventurer roninSlots displayName is '冒険者の勘'
      expect(find.textContaining('冒険者の勘'), findsWidgets);
    });

    testWidgets('equipped skill slot shows', (tester) async {
      await vm.load();
      vm.equipSkill(JobSkill.warriorCombo, debugMode: true);
      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.templeSkillSlotSection), findsOneWidget);
    });
  });
}
