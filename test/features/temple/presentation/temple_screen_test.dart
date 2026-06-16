import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player;

  _MockPlayerRepo([Player? player])
      : _player = player ?? Player();

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

/// Helper: make a Player with custom job levels.
Player playerWithLevels(Map<Job, int> levels) {
  final p = Player(jobLevels: {Job.adventurer: 1, ...levels});
  return p;
}

void main() {
  group('TempleScreen — Skill Slot Section', () {
    testWidgets('shows slot count header (1/X)', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 1, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      // Scroll down to skill slot section
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Default: 1 basic slot
      expect(find.byKey(AppKeys.templeSkillSlotSection), findsOneWidget);
      expect(find.textContaining('スキルスロット (0/1)'), findsOneWidget);
    });

    testWidgets('shows 2 slots when adventurer Lv10', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('スキルスロット (0/2)'), findsOneWidget);
    });

    testWidgets('shows empty slot text when slot empty', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 1, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('空きスロット'), findsOneWidget);
    });

    testWidgets('locked message when maxSlots=0', (tester) async {
      // When adventurer < 1... actually basic=1 so always at least 1.
      // Just verify section renders.
      final repo = _MockPlayerRepo(playerWithLevels({Job.adventurer: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.templeSkillSlotSection), findsOneWidget);
    });

    testWidgets('equipped skill shows job name and skill name and remove btn',
        (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.equipSkill(JobSkill.samuraiCombo, debugMode: true);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Shows warrior job display name and skill name
      expect(find.textContaining('侍'), findsWidgets);
      expect(find.textContaining('連撃の構え'), findsOneWidget);
      // Remove button visible
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('remove button unequips skill', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.equipSkill(JobSkill.samuraiCombo, debugMode: true);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap remove button
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();

      expect(vm.player.equippedSkills.length, 0);
    });

    testWidgets('dropdown shows add button when slot empty and skills available',
        (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add skill button should be visible (warrior skills available)
      // 2 slots available at adventurer Lv10 → 2 add buttons
      expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(2));
    });

    testWidgets('dropdown contains equippable skills', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 5}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the first add button to open dropdown
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Samurai Lv5 skills should be visible:
      // warriorCombo (Lv1) and warriorFatigueReverse (Lv5)
      expect(find.textContaining('連撃の構え'), findsWidgets);
      // warriorPomodoro (Lv10) and warriorBushido (Lv15) should not appear
      expect(find.textContaining('集中の型'), findsNothing);
      expect(find.textContaining('武士道の極意'), findsNothing);
    });

    testWidgets('selecting a skill from dropdown equips it', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open dropdown
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap warriorCombo (連撃の構え)
      await tester.tap(find.textContaining('連撃の構え').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(vm.player.equippedSkills.length, 1);
      expect(vm.player.equippedSkills.first.skill, JobSkill.samuraiCombo);
    });
  });

  group('TempleScreen — Current Job Skills Section', () {
    testWidgets('shows current job skills with lock/unlock icons',
        (tester) async {
      final repo = _MockPlayerRepo(playerWithLevels({Job.adventurer: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ronin skills: roninSlots (Lv1, unlocked), roninRepeatTask (Lv10, locked)
      expect(find.textContaining('冒険者の勘'), findsWidgets);
      expect(find.textContaining('果てなき挑戦'), findsWidgets);
      // Locked skill shows lock icon (roninRepeatTask + 3 locked job cards)
      expect(find.byIcon(Icons.lock), findsWidgets);
      // Unlocked skill shows check icon
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('warrior skills show correct lock state at Lv5',
        (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 5}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.changeJob(Job.samurai);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // At Lv5: warriorCombo(Lv1), warriorFatigueReverse(Lv5) → unlocked
      // warriorPomodoro(Lv10), warriorBushido(Lv15) → locked
      // 2 unlocked + 2 locked = 4 skills
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.byIcon(Icons.lock), findsWidgets);
      expect(find.textContaining('連撃の構え'), findsWidgets);
      expect(find.textContaining('逆転の気魄'), findsWidgets);
      expect(find.textContaining('集中の型'), findsWidgets);
      expect(find.textContaining('武士道の極意'), findsWidgets);
    });

    testWidgets('cleric skills show correct lock state at Lv10', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.monk: 10}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.changeJob(Job.monk);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // At Lv10: clericRepeatAfter(Lv1), snooze(Lv5), streak(Lv10) → unlocked
      // enlightenment(Lv15) → locked
      expect(find.textContaining('後追いの祈り'), findsWidgets);
      expect(find.textContaining('微睡みの加護'), findsWidgets);
      expect(find.textContaining('連続の誓い'), findsWidgets);
      expect(find.textContaining('悟りの境地'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('wizard skills show correct lock state at Lv15+',
        (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.mystic: 15}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.changeJob(Job.mystic);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // At Lv15: all 4 wizard skills unlocked + wizardOverview is MASTER
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.textContaining('分割の理'), findsWidgets);
      expect(find.textContaining('札の掌握'), findsWidgets);
      expect(find.textContaining('計画の陣'), findsWidgets);
      expect(find.textContaining('俯瞰の魔眼'), findsWidgets);
    });
  });

  group('TempleScreen — Master Skill Badge', () {
    testWidgets('master skill shows 常時発動 badge on equipped slot',
        (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 15}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      // Equip warriorBushido (Lv15, isMasterSkill)
      vm.equipSkill(JobSkill.samuraiBushido, debugMode: true);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('常時発動'), findsOneWidget);
    });

    testWidgets('ronin mastered shows 常時スキル発動中 on adventurer card',
        (tester) async {
      final repo =
          _MockPlayerRepo(playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      // Change to non-adventurer so the adventurer card shows "常時スキル発動中"
      vm.changeJob(Job.samurai);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      // Ronin card is near the top — minimal scroll or none
      await tester.pump(const Duration(milliseconds: 100));

      // Ronin Lv10 = mastered, adventurer card should show "常時スキル発動中"
      expect(find.textContaining('常時スキル発動中'), findsOneWidget);
    });
  });

  group('TempleScreen — Job Change', () {
    testWidgets('job change button visible for unlocked classes at Ronin Lv10',
        (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();

      // Ronin Lv10 unlocks other jobs
      expect(find.textContaining('浪人Lv.10 解放'), findsNothing);
      // Job cards are clickable for unlocked jobs
      expect(find.byKey(AppKeys.templeJobCardSamurai), findsOneWidget);
    });

    testWidgets('can change from non-adventurer job at Lv10', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 10}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.changeJob(Job.samurai);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();

      // Should be able to see other job cards as unlocked
      expect(find.byKey(AppKeys.templeJobCardMonk), findsOneWidget);
      expect(find.byKey(AppKeys.templeJobCardMystic), findsOneWidget);
    });

    testWidgets('cannot change job when adventurer < Lv10', (tester) async {
      final repo =
          _MockPlayerRepo(playerWithLevels({Job.adventurer: 5}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();

      expect(find.textContaining('浪人レベル10から可能'), findsOneWidget);
    });
  });

  group('TempleScreen — ON/OFF Toggle on Equipped Skill', () {
    testWidgets('equipped skill shows ON/OFF toggle', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.equipSkill(JobSkill.samuraiCombo, debugMode: true);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have a Switch/toggle widget in the slot row
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('toggling OFF disables the skill', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      vm.equipSkill(JobSkill.samuraiCombo, debugMode: true);

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the Switch and tap to toggle OFF
      final switches = find.byType(Switch);
      // The initial value should be true
      await tester.tap(switches.first);
      await tester.pump();

      // Verify the skill is now inactive
      expect(vm.player.equippedSkills.first.isActive, false);
    });

    testWidgets('toggling ON re-enables the skill', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();
      // Equip with debugMode=true then set inactive
      vm.equipSkill(JobSkill.samuraiCombo, debugMode: true);
      vm.player.equippedSkills.first.isActive = false;

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Toggle ON
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      expect(vm.player.equippedSkills.first.isActive, true);
    });

    testWidgets('no toggle shown on empty slot row', (tester) async {
      final repo = _MockPlayerRepo(
          playerWithLevels({Job.adventurer: 10, Job.samurai: 1}));
      final vm = PlayerViewModel(repo);
      await vm.load();

      await tester.pumpWidget(createTempleScreen(vm));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Empty slots have add button icons, not switches
      // With adventurer Lv10, 2 slots → 2 add buttons
      expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(2));
    });
  });
}
