import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_view_model.dart';
import '../widgets/help_dialog.dart';
import '../widgets/tutorial_overlay.dart';
import '../utils/tutorial_keys.dart';
import 'guild_screen.dart';
import 'home_screen.dart';
import 'temple_screen.dart';
import 'town_screen.dart';

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
  final PageController _pageController = PageController(initialPage: 0); // スワイプ用のページコントローラー

  final List<Widget> _screens = [
    const HomeScreen(),
    const GuildScreen(),
    const TempleScreen(),
    const TownScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  int? _renderedTutorialStep;
  Rect? _tutorialRect;
  int _retryCount = 0;
  int _stabilizeCount = 0;
  static const int _maxRetries = 20; // 2秒でタイムアウト
  static const int _stabilizeFrames = 5; // 500ms かけて位置が安定するまで追跡

  void _updateTutorialRect(int step, {bool resetRetry = true}) {
    if (resetRetry) {
      _retryCount = 0;
      _stabilizeCount = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GlobalKey? key;
      if (step == 0) {
        key = TutorialKeys.fabKey;
      } else if (step == 1) {
        key = TutorialKeys.acceptTaskKey;
      } else if (step == 2 && _currentIndex == 0) {
        key = TutorialKeys.battleCompleteKey;
      }

      if (key != null && key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.attached) {
          final offset = box.localToGlobal(Offset.zero);
          final rect = offset & box.size;

          // PageView 遷移直後はレイアウトが未確定で localToGlobal が不正確な値を返すことがある。
          // 画面内に収まった値を得るまで再測定し、さらに位置が安定するまで追跡する。
          final screenSize = MediaQuery.of(context).size;
          final isSane = rect.left >= 0 &&
              rect.top >= 0 &&
              rect.right <= screenSize.width + 1 &&
              rect.bottom <= screenSize.height + 1 &&
              rect.width > 0 &&
              rect.height > 0;

          if (!isSane) {
            // 画面外などありえない値 → 再測定
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _updateTutorialRect(step, resetRetry: false);
              });
            }
            return;
          }

          final sameRect = _tutorialRect == rect;
          if (!sameRect || _renderedTutorialStep != step) {
            setState(() {
              _tutorialRect = rect;
              _renderedTutorialStep = step;
            });
            _stabilizeCount = 0;
          } else {
            _stabilizeCount++;
          }

          // 位置が安定するまで毎フレーム再測定（PageView 遷移アニメの残像対策）
          if (_stabilizeCount < _stabilizeFrames) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _updateTutorialRect(step, resetRetry: false);
            });
          }
          return;
        }
      }

      if (step == 2 && _currentIndex != 0) {
        // 「戦場」タブへの誘導：BottomNavigationBar の最初のタブ（index 0）を指す
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final tabWidth = screenWidth / 4;
        final rect = Rect.fromLTWH(0,
            screenHeight - kBottomNavigationBarHeight - MediaQuery.of(context).padding.bottom,
            tabWidth, kBottomNavigationBarHeight);
        if (_tutorialRect != rect || _renderedTutorialStep != step) {
          setState(() {
            _tutorialRect = rect;
            _renderedTutorialStep = step;
          });
        }
        return;
      }

      // 該当 key がまだマウントされていない場合のフォールバック
      if (_retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _updateTutorialRect(step, resetRetry: false);
        });
      } else {
        // タイムアウト：FAB または受注ボタンを見つけられない → ギルドタブへ誘導
        if ((step == 0 || step == 1) && _currentIndex != 1) {
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Widget _buildTutorialOverlay(int step) {
    if (_tutorialRect == null || _renderedTutorialStep != step) {
      _updateTutorialRect(step);
      return const SizedBox.shrink();
    }

    String character = "阿国";
    String icon = "💃";
    String message = "";
    Alignment align = Alignment.center;

    if (step == 0) {
      character = "阿国"; icon = "💃";
      message = "新入りさんでありんすね！\nまずは右下の「＋」ボタンを押して、\n最初のクエストを登録するでありんす！";
      align = const Alignment(0, -0.2);
    } else if (step == 1) {
      character = "幸村"; icon = "🔥";
      message = "よくやったでござる！\n次は登録したクエストの「受注」ボタンを\nタップして、いざ出陣用意じゃ！";
      align = const Alignment(0, -0.5);
    } else if (step == 2 && _currentIndex != 0) {
      character = "官兵衛"; icon = "🧠";
      message = "クエストを受注したな。\nでは下のメニューから「戦場」へ移動し、\n討伐の準備を整えるでござる。";
      align = const Alignment(0, 0);
    } else if (step == 2 && _currentIndex == 0) {
      character = "誾千代"; icon = "⚡";
      message = "ここが戦場じゃ！\n準備ができたらクエストの「討伐(⚔️)」ボタンを\n押して任務を完了させるのじゃ！";
      align = const Alignment(0, -0.5);
    }

    return TutorialOverlay(
      targetRect: _tutorialRect!,
      characterName: character,
      avatarIcon: icon,
      message: message,
      dialogAlignment: align,
    );
  }

  @override
  void dispose() {
    // リソースを解放
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);

    if (!viewModel.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_didJumpToGuildForTutorial) {
      _didJumpToGuildForTutorial = true;
      if (viewModel.tutorialStep <= 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _currentIndex = 1);
            _pageController.jumpToPage(1);
          }
        });
      }
    }

    if (!viewModel.hasSeenConcept && !_isHelpDialogShowing) {
      _isHelpDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showHelpDialog(context).then((_) {
          viewModel.markConceptAsSeen();
          // ヘルプダイアログ後、チュートリアル選択ダイアログを表示
          if (mounted && viewModel.tutorialStep <= 2 && !viewModel.tutorialSkipped && !_isTutorialChoiceShowing) {
            setState(() => _isTutorialChoiceShowing = true);
            _showTutorialChoiceDialog();
          }
        });
      });
    } else if (viewModel.hasSeenConcept && viewModel.tutorialStep <= 2 && !viewModel.tutorialSkipped && !_isTutorialChoiceShowing) {
      _isTutorialChoiceShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTutorialChoiceDialog();
      });
    } else if (viewModel.pendingLoginBonusAmount != null) {
      final amount = viewModel.pendingLoginBonusAmount!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        viewModel.clearPendingLoginBonus();
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: '',
          barrierColor: Colors.black87,
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, anim1, anim2) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('＼ 本日の恩賞 ／', style: TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('💰 +$amount 金貨', style: const TextStyle(color: Colors.amber, fontSize: 48, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('ありがたき幸せ！', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
          transitionBuilder: (context, anim1, anim2, child) {
            return Transform.scale(
              scale: Curves.elasticOut.transform(anim1.value),
              child: child,
            );
          },
        );
      });
    } else if (viewModel.pendingStreakReward != null) {
      // ストリーク節目報酬ダイアログ
      final reward = viewModel.pendingStreakReward!;
      final streak = viewModel.streakDays;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        viewModel.clearPendingStreakReward();
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: '',
          barrierColor: Colors.black87,
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, anim1, anim2) {
            final milestoneEmoji = streak >= 30
                ? '⭐'
                : streak >= 14
                    ? '🌟'
                    : streak >= 7
                        ? '🔥'
                        : '✨';
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: streak >= 30
                          ? [Colors.purple[900]!, Colors.amber[700]!, Colors.purple[900]!]
                          : [Colors.orange[900]!, Colors.deepOrange[700]!, Colors.orange[900]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: streak >= 7 ? Colors.orange : Colors.amber,
                        blurRadius: streak >= 30 ? 48 : 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(milestoneEmoji, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Text(
                        '$streak日連続ログイン！',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '💰 +$reward 金貨',
                        style: const TextStyle(color: Colors.amber, fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange[900],
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('受け取る！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, anim1, anim2, child) {
            return Transform.scale(
              scale: Curves.elasticOut.transform(anim1.value),
              child: Opacity(opacity: anim1.value.clamp(0.0, 1.0), child: child),
            );
          },
        );
      });
    }

    return Stack(
      children: [
        Scaffold(
          // 画面をスワイプできるようにPageViewを利用する
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (viewModel.tutorialStep <= 2) {
                 _renderedTutorialStep = -1; // Force tutorial update on tab change
                 _updateTutorialRect(viewModel.tutorialStep);
              }
            },
            children: _screens,
          ),
          // BottomNavigationBarを追加（Add BottomNavigationBar for smartphones）
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (viewModel.tutorialStep <= 2) {
                 _renderedTutorialStep = -1;
                 _updateTutorialRect(viewModel.tutorialStep);
              }
              // タブがタップされたときにスワイプアニメーションでページを切り替える
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: '戦場',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'ギルド',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.temple_buddhist),
                label: '神殿',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store),
                label: '街',
              ),
            ],
            type: BottomNavigationBarType.fixed, // タブが4つ以上の場合のアニメーションを防ぐ
            selectedItemColor: Colors.amber[700],
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.black87,
        ),
      ),
      if (viewModel.tutorialStep <= 2 && !viewModel.tutorialSkipped) ...[
        _buildTutorialOverlay(viewModel.tutorialStep),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => viewModel.skipTutorial(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next, color: Colors.white70, size: 18),
                      SizedBox(width: 4),
                      Text('スキップ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

void _showTutorialChoiceDialog() {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('📜', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('チュートリアル'),
          ],
        ),
        content: const Text('冒険の基本を学びますか？\n（初めてプレイする方は「学ぶ」を推奨）'),
        actions: [
          TextButton(
            onPressed: () {
              viewModel.skipTutorial();
              Navigator.pop(ctx);
              setState(() => _isTutorialChoiceShowing = false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('スキップ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isTutorialChoiceShowing = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('学ぶ'),
          ),
        ],
      ),
    );
  }
}
