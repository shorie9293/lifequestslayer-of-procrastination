import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/shared/widgets/debug_panel.dart';
import 'widgets/main_bottom_nav.dart';
import 'widgets/main_tutorial_controller.dart';
import 'package:rpg_todo/features/temple/presentation/dialogs/job_tutorial_dialog.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

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
    final settingsVM = context.read<SettingsViewModel>();
    if (settingsVM.tutorialStep <= 2) {
      _tutorialController.renderedTutorialStep = -1;
      _tutorialController.updateTutorialRect(
        step: settingsVM.tutorialStep, context: context,
        pageController: _pageController, setState: () => setState(() {}), mounted: mounted,
      );
    }
    if (animate) _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Widget _skipTutorialBtn(SettingsViewModel settingsVM) => Positioned(
    top: MediaQuery.of(context).padding.top + 8, right: 16,
    child: SafeArea(child: Material(color: Colors.transparent, child: SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(SemanticTypes.button, 'skip_tutorial'),
      label: '導きの書を略する',
        child: InkWell(
        key: AppKeys.tutorialSkip, onTap: settingsVM.skipTutorial, borderRadius: BorderRadius.circular(20),
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
    final playerVM = context.watch<PlayerViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();
    final isLoaded = playerVM.isLoaded && context.read<TaskViewModel>().isLoaded;
    if (!isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    _tutorialController.currentIndex = _currentIndex;

    if (!_didJumpToGuildForTutorial) {
      _didJumpToGuildForTutorial = true;
      if (settingsVM.tutorialStep <= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { setState(() => _currentIndex = 1); _pageController.jumpToPage(1); }
        });
      }
    }

    if (!settingsVM.hasSeenConcept && !_isHelpDialogShowing) {
      _isHelpDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showHelpDialog(context).then((_) {
          settingsVM.markConceptAsSeen();
          if (mounted && settingsVM.tutorialStep <= 2 && !settingsVM.tutorialChoiceMade) {
            setState(() => _isTutorialChoiceShowing = true);
            _showTutorialChoiceDialog(settingsVM);
          }
        });
      });
    } else if (settingsVM.hasSeenConcept && settingsVM.tutorialStep <= 2 && !settingsVM.tutorialChoiceMade && !_isTutorialChoiceShowing) {
      _isTutorialChoiceShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showTutorialChoiceDialog(settingsVM); });
    } else if (playerVM.pendingLoginBonusAmount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { final a = playerVM.pendingLoginBonusAmount!; playerVM.clearPendingLoginBonus(); _showLoginBonusDialog(a); });
    } else if (playerVM.pendingStreakReward != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { final r = playerVM.pendingStreakReward!; playerVM.clearPendingStreakReward(); _showStreakRewardDialog(r, playerVM.streakDays); });
    } else if (settingsVM.showJobTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showJobTutorialDialog(
            context,
            onClose: () {
              settingsVM.markJobTutorialSeen();
              setState(() {});
            },
            jobTutorialCompleted: settingsVM.jobTutorialCompleted,
            onSkip: () {
              settingsVM.markJobTutorialSeen();
              setState(() {});
            },
          );
        }
      });
    }

    return Stack(children: [
      Scaffold(
        body: PageView(controller: _pageController, onPageChanged: _onPageChanged, children: _screens),
        bottomNavigationBar: MainBottomNav(currentIndex: _currentIndex, onTabChanged: (i) => _onPageChanged(i, animate: true)),
      ),
      // デバッグモード起動ボタン（右上ギアアイコン）
      Positioned(
        top: MediaQuery.of(context).padding.top + 4,
        right: 4,
        child: SafeArea(
          child: Semantics(
            label: 'デバッグモード',
            child: IconButton(
              icon: Icon(Icons.settings, color: settingsVM.isDebugMode ? Colors.amber : Colors.white24, size: 20),
              onPressed: settingsVM.isDebugMode ? () => _showDebugPanel(settingsVM) : () => _showDebugPasswordDialog(settingsVM),
              tooltip: settingsVM.isDebugMode ? 'デバッグパネルを開く' : 'デバッグモード',
            ),
          ),
        ),
      ),
      if (settingsVM.tutorialStep <= 2 && !settingsVM.tutorialSkipped) ...[
        _tutorialController.buildTutorialOverlay(settingsVM.tutorialStep, _currentIndex),
        _skipTutorialBtn(settingsVM),
      ],
    ]);
  }

  void _showTutorialChoiceDialog(SettingsViewModel settingsVM) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Text('📜', style: TextStyle(fontSize: 24)), SizedBox(width: 8), Text('導きの書')]),
        content: const Text('修練の基本を指南を受けますか？\n（初めてプレイする方は「指南を受ける」を推奨）'),
        actions: [
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'skip_tutorial_inline'),
            label: 'チュートリアルを略する',
            child: TextButton(
              key: AppKeys.tutorialSkip,
              onPressed: () async {
                final nav = Navigator.of(ctx);
                await settingsVM.skipTutorial();
                if (mounted) { nav.pop(); setState(() => _isTutorialChoiceShowing = false); }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('略する'),
            ),
          ),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'start_tutorial_inline'),
            label: 'チュートリアルを開始',
            child: ElevatedButton(
              key: AppKeys.tutorialUnderstood,
              onPressed: () async {
                final nav = Navigator.of(ctx);
                await settingsVM.markTutorialChoiceMade();
                if (mounted) { nav.pop(); setState(() => _isTutorialChoiceShowing = false); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
              child: const Text('指南を受ける'),
            ),
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
    // ── ストリーク称号（UX-10） ──
    String? streakTitle;
    String? legendMessage;
    if (streak >= 100) {
      streakTitle = '【称号】時の支配者';
      legendMessage = '伝説の領域へ⋯⋯時の流れすら味方につけた冒険者よ、\nその歩みはもはや神話の一節なり。';
    } else if (streak >= 60) {
      streakTitle = '【称号】継続の達人';
      legendMessage = '継続こそ最大の力。二ヶ月の積み重ねが、\n凡人の域を超えた達人の境地を開く。';
    } else if (streak >= 30) {
      streakTitle = '【称号】月を跨ぎし者';
      legendMessage = '一ヶ月を超えし者にのみ与えられし称号。\n日々の積み重ねが、ここに一つの伝説を刻む。';
    }
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
            if (streakTitle != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Text(streakTitle, style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
            if (legendMessage != null) ...[
              const SizedBox(height: 8),
              Text(legendMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic)),
            ],
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

  void _showDebugPasswordDialog(SettingsViewModel settingsVM) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('デバッグモード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('合言葉を入力せよ'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '合言葉',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('戻る')),
          ElevatedButton(
            onPressed: () {
              if (settingsVM.tryEnableDebugMode(controller.text)) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('デバッグモード起動！制限解除されました'), duration: Duration(seconds: 2)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('合言葉が違います'), duration: Duration(seconds: 1)),
                );
              }
            },
            child: const Text('起動'),
          ),
        ],
      ),
    );
  }

  void _showDebugPanel(SettingsViewModel settingsVM) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DebugPanel(settingsVM: settingsVM),
    );
  }
}
