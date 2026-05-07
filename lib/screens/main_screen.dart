import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/error/error_boundary.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'widgets/main_bottom_nav.dart';
import 'widgets/main_tutorial_controller.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isHelpDialogShowing = false;
  bool _isTutorialChoiceShowing = false;
  bool _didJumpToGuildForTutorial = false;
  final PageController _pageController = PageController(initialPage: 0);
  final MainTutorialController _tutorialController = MainTutorialController();

  final List<Widget> _screens = [
    const ErrorBoundary(child: BattleScreen()),
    const ErrorBoundary(child: GuildScreen()),
    const ErrorBoundary(child: TempleScreen()),
    const ErrorBoundary(child: TownScreen()),
  ];

  @override
  void initState() => super.initState();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, {bool animate = false}) {
    setState(() => _currentIndex = index);
    final vm = Provider.of<GameViewModel>(context, listen: false);
    if (vm.tutorialStep <= 2) {
      _tutorialController.renderedTutorialStep = -1;
      _tutorialController.updateTutorialRect(
        step: vm.tutorialStep, context: context,
        pageController: _pageController, setState: () => setState(() {}), mounted: mounted,
      );
    }
    if (animate) _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Widget _skipTutorialBtn(GameViewModel vm) => Positioned(
    top: MediaQuery.of(context).padding.top + 8, right: 16,
    child: SafeArea(child: Material(color: Colors.transparent, child: SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(SemanticTypes.button, 'skip_tutorial'),
      label: '導きの書を略する',
      child: InkWell(
        key: AppKeys.tutorialSkip, onTap: vm.skipTutorial, borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.skip_next, color: Colors.white70, size: 18), SizedBox(width: 4),
            Text('略する', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
      ),
    ))),
  );

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<GameViewModel>(context);
    if (!vm.isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    _tutorialController.currentIndex = _currentIndex;

    if (!_didJumpToGuildForTutorial) {
      _didJumpToGuildForTutorial = true;
      if (vm.tutorialStep <= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { setState(() => _currentIndex = 1); _pageController.jumpToPage(1); }
        });
      }
    }

    if (!vm.hasSeenConcept && !_isHelpDialogShowing) {
      _isHelpDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showHelpDialog(context).then((_) {
          vm.markConceptAsSeen();
          if (mounted && vm.tutorialStep <= 2 && !vm.tutorialChoiceMade) {
            setState(() => _isTutorialChoiceShowing = true);
            _showTutorialChoiceDialog(vm);
          }
        });
      });
    } else if (vm.hasSeenConcept && vm.tutorialStep <= 2 && !vm.tutorialChoiceMade && !_isTutorialChoiceShowing) {
      _isTutorialChoiceShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showTutorialChoiceDialog(vm); });
    } else if (vm.pendingLoginBonusAmount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { vm.clearPendingLoginBonus(); _showLoginBonusDialog(vm.pendingLoginBonusAmount!); });
    } else if (vm.pendingStreakReward != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { vm.clearPendingStreakReward(); _showStreakRewardDialog(vm.pendingStreakReward!, vm.streakDays); });
    }

    return Stack(children: [
      Scaffold(
        body: PageView(controller: _pageController, onPageChanged: _onPageChanged, children: _screens),
        bottomNavigationBar: MainBottomNav(currentIndex: _currentIndex, onTabChanged: (i) => _onPageChanged(i, animate: true)),
      ),
      if (vm.tutorialStep <= 2 && !vm.tutorialSkipped) ...[
        _tutorialController.buildTutorialOverlay(vm.tutorialStep, _currentIndex),
        _skipTutorialBtn(vm),
      ],
    ]);
  }

  void _showTutorialChoiceDialog(GameViewModel vm) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Text('📜', style: TextStyle(fontSize: 24)), SizedBox(width: 8), Text('導きの書')]),
        content: const Text('修練の基本を指南を受けますか？\n（初めてプレイする方は「指南を受ける」を推奨）'),
        actions: [
          TextButton(
            key: AppKeys.tutorialSkip,
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await vm.skipTutorial();
              if (mounted) { nav.pop(); setState(() => _isTutorialChoiceShowing = false); }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('略する'),
          ),
          ElevatedButton(
            key: AppKeys.tutorialUnderstood,
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await vm.markTutorialChoiceMade();
              if (mounted) { nav.pop(); setState(() => _isTutorialChoiceShowing = false); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
            child: const Text('指南を受ける'),
          ),
        ],
      ),
    );
  }

  void _showLoginBonusDialog(int amount) {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: '', barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (ctx, a1, a2) => Center(
        child: Material(color: Colors.transparent, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('＼ 本日の賜り物 ／', style: TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('💰 +$amount 文', style: const TextStyle(color: Colors.amber, fontSize: 48, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(SemanticTypes.button, 'claim_login_bonus'), label: 'ボーナスを受け取る',
            child: ElevatedButton(
              key: AppKeys.tutorialReward,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ありがたき幸せ！', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ])),
      ),
      transitionBuilder: (ctx, a1, a2, c) => Transform.scale(scale: Curves.elasticOut.transform(a1.value), child: c),
    );
  }

  void _showStreakRewardDialog(int reward, int streak) {
    final emoji = streak >= 30 ? '⭐' : streak >= 14 ? '🌟' : streak >= 7 ? '🔥' : '✨';
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: '', barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (ctx, a1, a2) => Center(
        child: Material(color: Colors.transparent, child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: streak >= 30
                  ? [Colors.purple[900]!, Colors.amber[700]!, Colors.purple[900]!]
                  : [Colors.orange[900]!, Colors.deepOrange[700]!, Colors.orange[900]!],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: streak >= 7 ? Colors.orange : Colors.amber, blurRadius: streak >= 30 ? 48 : 32, spreadRadius: 4)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text('$streak日連続ログイン！', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('💰 +$reward 文', style: const TextStyle(color: Colors.amber, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId(SemanticTypes.button, 'claim_streak_reward'), label: 'ストリーク報酬を受け取る',
              child: ElevatedButton(
                key: AppKeys.closeButton,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.orange[900], padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('受け取る！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        )),
      ),
      transitionBuilder: (ctx, a1, a2, c) => Transform.scale(scale: Curves.elasticOut.transform(a1.value), child: Opacity(opacity: a1.value.clamp(0.0, 1.0), child: c)),
    );
  }
}
