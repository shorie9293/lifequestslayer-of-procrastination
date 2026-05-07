import 'package:flutter/material.dart';
import 'package:rpg_todo/features/shared/widgets/tutorial_overlay.dart';
import 'package:rpg_todo/core/testing/tutorial_keys.dart';

/// チュートリアルのオーバーレイ表示と位置計算を担当するコントローラー。
class MainTutorialController {
  int? renderedTutorialStep;
  Rect? tutorialRect;
  int _retryCount = 0;
  int _stabilizeCount = 0;
  static const int _maxRetries = 20;
  static const int _stabilizeFrames = 5;

  int currentIndex = 0;

  void reset() {
    renderedTutorialStep = null;
    tutorialRect = null;
    _retryCount = 0;
    _stabilizeCount = 0;
  }

  void resetRetry() {
    _retryCount = 0;
    _stabilizeCount = 0;
  }

  void updateTutorialRect({
    required int step,
    required BuildContext context,
    required PageController pageController,
    required VoidCallback setState,
    required bool mounted,
    bool resetRetry = true,
  }) {
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
      } else if (step == 2 && currentIndex == 0) {
        key = TutorialKeys.battleCompleteKey;
      }

      if (key != null && key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.attached) {
          final offset = box.localToGlobal(Offset.zero);
          final rect = offset & box.size;

          final screenSize = MediaQuery.of(context).size;
          final isSane = rect.left >= 0 &&
              rect.top >= 0 &&
              rect.right <= screenSize.width + 1 &&
              rect.bottom <= screenSize.height + 1 &&
              rect.width > 0 &&
              rect.height > 0;

          if (!isSane) {
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  updateTutorialRect(
                    step: step,
                    context: context,
                    pageController: pageController,
                    setState: setState,
                    mounted: mounted,
                    resetRetry: false,
                  );
                }
              });
            }
            return;
          }

          final sameRect = tutorialRect == rect;
          if (!sameRect || renderedTutorialStep != step) {
            setState();
            tutorialRect = rect;
            renderedTutorialStep = step;
            _stabilizeCount = 0;
          } else {
            _stabilizeCount++;
          }

          if (_stabilizeCount < _stabilizeFrames) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                updateTutorialRect(
                  step: step,
                  context: context,
                  pageController: pageController,
                  setState: setState,
                  mounted: mounted,
                  resetRetry: false,
                );
              }
            });
          }
          return;
        }
      }

      if (step == 2 && currentIndex != 0) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final tabWidth = screenWidth / 4;
        final rect = Rect.fromLTWH(
          0,
          screenHeight -
              kBottomNavigationBarHeight -
              MediaQuery.of(context).padding.bottom,
          tabWidth,
          kBottomNavigationBarHeight,
        );
        if (tutorialRect != rect || renderedTutorialStep != step) {
          setState();
          tutorialRect = rect;
          renderedTutorialStep = step;
        }
        return;
      }

      if (_retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            updateTutorialRect(
              step: step,
              context: context,
              pageController: pageController,
              setState: setState,
              mounted: mounted,
              resetRetry: false,
            );
          }
        });
      } else {
        if ((step == 0 || step == 1) && currentIndex != 1) {
          pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Widget buildTutorialOverlay(int step, int currentIndex) {
    if (tutorialRect == null || renderedTutorialStep != step) {
      return const SizedBox.shrink();
    }

    String character = "阿国";
    String icon = "💃";
    String message = "";
    Alignment align = Alignment.center;

    if (step == 0) {
      character = "阿国";
      icon = "💃";
      message = "新入りさんでありんすね！\nまずは右下の「＋」ボタンを押して、\n最初のクエストを登録するでありんす！";
      align = const Alignment(0, -0.2);
    } else if (step == 1) {
      character = "幸村";
      icon = "🔥";
      message = "よくやったでござる！\n次は登録したクエストの「受注」ボタンを\nタップして、いざ出陣用意じゃ！";
      align = const Alignment(0, -0.5);
    } else if (step == 2 && currentIndex != 0) {
      character = "官兵衛";
      icon = "🧠";
      message = "クエストを受注したな。\nでは下のメニューから「戦場」へ移動し、\n討伐の準備を整えるでござる。";
      align = const Alignment(0, 0);
    } else if (step == 2 && currentIndex == 0) {
      character = "誾千代";
      icon = "⚡";
      message = "ここが戦場じゃ！\n準備ができたらクエストの「討伐(⚔️)」ボタンを\n押して任務を完了させるのじゃ！";
      align = const Alignment(0, -0.5);
    }

    return TutorialOverlay(
      targetRect: tutorialRect!,
      characterName: character,
      avatarIcon: icon,
      message: message,
      dialogAlignment: align,
    );
  }
}
