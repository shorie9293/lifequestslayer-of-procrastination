import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/player_status_header.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'widgets/battle_report_dialog.dart';
import 'widgets/particle_effect.dart';
import 'widgets/combat_selection_bar.dart';
import 'widgets/fatigue_gem_popup.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/battle/domain/battle_action.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:rpg_todo/core/testing/tutorial_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// M4禍津対策: 連打ガード用セット
final Set<String> _completingTaskIds = {};

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with WidgetsBindingObserver {
  late final BattleViewModel _battleVM;
  late final BattleAudioService _audioService;

  /// 現在戦術選択フェイズにあるクエストのID。
  /// null の場合は通常のクエスト一覧表示。
  String? _taskInCombat;

  Color _getRankColor(QuestRank rank) => RankColors.forRank(rank);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _battleVM = getIt<BattleViewModel>();
    _audioService = getIt<BattleAudioService>();

    // BattleAudioServiceの変化でUIを再描画
    _audioService.addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _audioService.stopAll();
    }
  }

  /// BattleAudioServiceの状態変化でUIを再描画する。
  void _onAudioChanged() {
    setState(() {});
  }

  /// 戦術選択バーを表示して討伐フェイズに移行する。
  /// 戦闘シーンOFFの場合は即討伐完了する。
  void _enterCombatPhase(String taskId) {
    if (_battleVM.isInCombat) return;

    final settingsVM = context.read<SettingsViewModel>();

    if (!settingsVM.isBattleSceneEnabled) {
      // 戦闘シーンOFF → 即討伐
      _completeTask(context, taskId);
      return;
    }

    final taskVM = context.read<TaskViewModel>();
    final task = taskVM.activeTasks.firstWhere((t) => t.id == taskId);

    _battleVM.enterBattle(task);
    setState(() {
      _taskInCombat = taskId;
    });
  }

  /// 戦術が選択された時の処理。
  /// [action] に応じた補正を行った後、既存の討伐フローを実行する。
  void _onActionSelected(BattleAction action) {
    final taskId = _taskInCombat;
    if (taskId == null) return;

    // 戦術をBattleViewModelに登録
    _battleVM.selectTactic(_mapActionToTactic(action));

    // 戦術選択UIを閉じる
    setState(() {
      _taskInCombat = null;
    });

    // TODO(v2.1): actionに応じたEXP/討伐成功率補正をTaskViewModelに反映する。
    // 現時点ではアクション選択UIのみ実装。討伐フローは既存のまま。
    // 例: attack → 標準, defend → EXP * 0.7 + 討伐成功率UP, skill → 装備スキル効果発動

    _completeTask(context, taskId);
  }

  /// [BattleAction] を [BattleTactic] に変換する。
  BattleTactic _mapActionToTactic(BattleAction action) {
    switch (action) {
      case BattleAction.attack:
        return BattleTactic.attack;
      case BattleAction.defend:
        return BattleTactic.defend;
      case BattleAction.skill:
        return BattleTactic.skill;
    }
  }

  void _completeTask(BuildContext context, String taskId) {
    // M4禍津対策: 連打ガード。同一クエストの二重実行を防止する。
    if (_completingTaskIds.contains(taskId)) return;
    _completingTaskIds.add(taskId);

    final taskVM = context.read<TaskViewModel>();
    final playerVM = context.read<PlayerViewModel>();
    final gameVM = context.read<GameViewModel>();

    // 重要: この関数は非同期ダイアログ/SnackBar を多数スケジュールする。
    // クエスト討伐後に ListView から当該アイテムが dispose されると `context` が unmounted になるため、
    // Navigator / ScaffoldMessenger は関数冒頭で捕捉しておく（Flutter 公式の async callback パターン）。
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final wasActive = taskVM.activeTasks.any((t) => t.id == taskId);
    if (!wasActive) {
      _completingTaskIds.remove(taskId);
      return;
    }

    // レベルアップ前のレベルを記録（completeTask 後に比較するため）
    final previousLevel = playerVM.player.level;

    final result = gameVM.completeTask(taskId);

    if (result == null) {
      // 討伐失敗 → BattleViewModelに敗北を通知 + SFX再生
      _battleVM.declareDefeat(
        penaltyExp: 0,
        bonusMessages: const [],
      );
      _audioService.playDefeat();

      final stillActive = taskVM.activeTasks.any((t) => t.id == taskId);
      if (stillActive) {
        final task = taskVM.activeTasks.firstWhere((t) => t.id == taskId);
        if (task.subTasks.any((s) => !s.isCompleted)) {
          // UX-3: 討伐失敗時、未完了サブクエストの名前を表示
          final remaining = task.subTasks
              .where((s) => !s.isCompleted)
              .map((s) => '・${s.title}')
              .join('\n');
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("サブクエストが残っています:\n$remaining"),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      _completingTaskIds.remove(taskId);
      return;
    }

    final leveledUp = result['leveledUp'] as bool;
    final coinsGained = result['coinsGained'] as int;
    final bonusMessages = result['bonusMessages'] as List<String>;
    final quizQuestion = result['quizQuestion'] as QuizQuestion?;
    final baseExp = result['baseExp'] as int;
    final isOverdueBoss = result['isOverdueBoss'] as bool? ?? false;
    final wrongAnswerPenaltyExp =
        result['wrongAnswerPenaltyExp'] as int? ?? 0;
    final wrongAnswerPenaltyCoins =
        result['wrongAnswerPenaltyCoins'] as int? ?? 0;
    final showFatiguePopup = result['showFatiguePopup'] as bool? ?? false;

    // 討伐成功 → BattleViewModelに勝利を通知 + SFX再生
    _battleVM.declareVictory(
      expGained: baseExp,
      coinsGained: coinsGained,
      bonusMessages: bonusMessages,
    );
    _audioService.playVictory();

    // UX-6: 戦果報告書の統合 — SnackBarを廃止し、全てのフィードバックを戦果報告書ダイアログに集約

    // 討伐完了パーティクルエフェクト → 戦果報告書（統合ダイアログ）
    // navigator を事前捕捉してあるので、リスト項目が dispose されても確実に pop できる。
    final dialogContext = navigator.context;
    bool effectClosed = false;

    Future<void> showBattleReport() async {
      if (!dialogContext.mounted) return;
      final player = playerVM.player;
      // 疲労警告用の判定
      final warnThresh = playerVM.fatigueWarnThreshold;
      final severeThresh = playerVM.fatigueSevereThreshold;
      final dailyDone = player.dailyTasksCompleted;
      String? fatigueWarning;
      if (dailyDone >= severeThresh) {
        fatigueWarning = '疲労が限界に達しています。宿屋で休むことをお勧めします。';
      } else if (dailyDone >= warnThresh) {
        fatigueWarning = '疲れが溜まってきました。宿屋で一息つきませんか？';
      }

      await BattleReportDialog.show(
        dialogContext,
        coinsGained: coinsGained,
        bonusMessages: bonusMessages,
        leveledUp: leveledUp,
        previousLevel: previousLevel,
        newLevel: player.level,
        currentExp: player.currentExp,
        expToNextLevel: player.expToNextLevel,
        quizQuestion: quizQuestion,
        onQuizCorrect: quizQuestion != null
            ? (q) {
                taskVM.awardKnowledgeBonus(q.expBonusPercent, baseExp);
                taskVM.save();
                // 刻の番人討伐時は称号チェック
                if (isOverdueBoss) {
                  playerVM.defeatTimeWarden();
                  playerVM.save();
                }
              }
            : null,
        onQuizWrong: (isOverdueBoss && wrongAnswerPenaltyExp > 0)
            ? () {
                playerVM.applyWrongAnswerPenalty(
                    wrongAnswerPenaltyExp, wrongAnswerPenaltyCoins);
                playerVM.save();
              }
            : null,
        isOverdueBoss: isOverdueBoss,
        baseExp: baseExp,
        fatigueWarning: fatigueWarning,
        fatigueWarnThreshold: warnThresh,
        dailyTasksCompleted: dailyDone,
      );

      // 戦果報告書を閉じた後、バトル状態をアイドルに戻す
      _battleVM.dismissResult();

      // UX-12: 疲労ポップアップを戦果報告書の後に表示
      // rootNavigator経由で二重遷移を防止する
      if (showFatiguePopup && dialogContext.mounted) {
        await FatigueGemPopup.show(dialogContext);
      }
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: ParticleBurst(
            onComplete: () {
              // M5禍津対策: maybePop() は最上面のルートを閉じてしまう。
              // 無関係なダイアログ（知識クエスト等）を閉じないよう、
              // ParticleBurst のコンテキストで明示的に pop する。
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    ).then((_) {
      // エフェクトが閉じられた後に戦果報告書を表示
      if (effectClosed) return;
      effectClosed = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        showBattleReport();
      });
      // ガード解除: ダイアログ連鎖完了後に解放
      _completingTaskIds.remove(taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();
    final tasks = taskVM.activeTasks;

    // UX-9: save()失敗時のSnackBar表示コールバック
    if (taskVM.onSaveError == null) {
      final messenger = ScaffoldMessenger.of(context);
      taskVM.onSaveError = () {
        messenger.showSnackBar(
          const SnackBar(content: Text("クエストデータの保存に失敗しました")),
        );
      };
    }
    final playerVM = context.read<PlayerViewModel>();
    if (playerVM.onSaveError == null) {
      final messenger = ScaffoldMessenger.of(context);
      playerVM.onSaveError = () {
        messenger.showSnackBar(
          const SnackBar(content: Text("プレイヤーデータの保存に失敗しました")),
        );
      };
    }

    // 戦術選択フェイズのときは選択中のクエストをハイライト
    final bool isInCombat = _taskInCombat != null;

    return Scaffold(
      key: AppKeys.battleScreen,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isInCombat ? "⚔️ 戦術選択" : "修練場",
            key: ValueKey(isInCombat),
          ),
        ),
        actions: [
          // 効果音トグル（SettingsViewModel連動）
          Consumer<SettingsViewModel>(
            builder: (context, settings, _) {
              return IconButton(
                icon: Icon(
                  settings.isSfxEnabled
                      ? Icons.volume_up
                      : Icons.volume_off,
                  color: settings.isSfxEnabled
                      ? Colors.amberAccent
                      : Colors.grey,
                  size: 20,
                ),
                tooltip: settings.isSfxEnabled
                    ? '効果音を消す'
                    : '効果音をつける',
                onPressed: () {
                  settings.setSfxEnabled(!settings.isSfxEnabled);
                  _audioService.setSfxEnabled(!settings.isSfxEnabled);
                },
              );
            },
          ),
          // 戦闘シーントグル
          Consumer<SettingsViewModel>(
            builder: (context, settings, _) {
              return IconButton(
                icon: Icon(
                  settings.isBattleSceneEnabled
                      ? Icons.sports_kabaddi
                      : Icons.flash_on,
                  color: settings.isBattleSceneEnabled
                      ? Colors.amberAccent
                      : Colors.orangeAccent,
                  size: 20,
                ),
                tooltip: settings.isBattleSceneEnabled
                    ? '戦闘シーン：ON（タップで即討伐に）'
                    : '戦闘シーン：OFF（即討伐）',
                onPressed: () =>
                    settings.setBattleSceneEnabled(
                        !settings.isBattleSceneEnabled),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '神託補佐（ヘルプ）',
            onPressed: () =>
                showHelpDialog(context, screen: HelpScreen.battle),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/home_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            // Player Stats Header
            const PlayerStatusHeader(),

            // Active Tasks (Monsters)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: tasks.isEmpty
                    ? const Center(
                        key: AppKeys.battleEmptyState,
                        child: Text(
                          "クエストがありません。\n寄合所で受注してください！",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        ),
                      )
                    : Column(
                        key: const ValueKey('task_list'),
                        children: [
                          // 今日の見積もり時間
                          if (taskVM.dailyEstimatedMinutes > 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              color: Colors.black26,
                              child: Row(
                                children: [
                                  const Text("📊",
                                      style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(
                                    "今日の戦い（見積もり）: ${taskVM.dailyEstimatedMinutes}分",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              key: AppKeys.battleActiveTaskList,
                              padding: const EdgeInsets.all(16),
                              itemCount: tasks.length,
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                final isInSelection =
                                    _taskInCombat == task.id;
                                return AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  transform: isInSelection
                                      ? (Matrix4.identity()..scale(1.03))
                                      : Matrix4.identity(),
                                  child: TaskCard(
                                    task: task,
                                    color: _getRankColor(task.rank),
                                    onSubTaskToggle: (idx, _) {
                                      taskVM.toggleSubTask(task.id, idx);
                                      taskVM.save();
                                    },
                                    actions: [
                                      SemanticHelper.interactive(
                                        testId: SemanticHelper.createTestId(
                                            SemanticTypes.button,
                                            'cancel_task'),
                                        label: 'クエストを寄合所に戻す',
                                        child: IconButton(
                                          key: AppKeys.battleCancel,
                                          icon: const Icon(Icons.undo,
                                              color: Colors.grey),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                key: AppKeys.confirmDialog,
                                                title: const Text(
                                                    "クエストを戻す"),
                                                content: const Text(
                                                    "このクエストを寄合所に戻しますか？\n\n⚠ 撤退には体力を消耗します（討伐1回分と同量）"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text(
                                                        "キャンセル"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      // 体力消費：1クエスト完了分
                                                      playerVM
                                                              .player
                                                              .dailyTasksCompleted++;
                                                      playerVM.save();
                                                      taskVM.cancelTask(
                                                          task.id);
                                                      taskVM.save();
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "クエストを寄合所に戻しました（体力を消耗した…）")),
                                                      );
                                                    },
                                                    child: const Text(
                                                        "戻す（体力消費）",
                                                        style: TextStyle(
                                                            color: Colors
                                                                .orange)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          tooltip: "寄合所に戻す",
                                        ),
                                      ),
                                      SemanticHelper.interactive(
                                        testId: SemanticHelper.createTestId(
                                            SemanticTypes.button,
                                            'complete_task'),
                                        label: '討つ！',
                                        child: IconButton(
                                          key: index == 0
                                              ? TutorialKeys
                                                  .battleCompleteKey
                                              : null,
                                          icon: const Text('⚔️',
                                              style:
                                                  TextStyle(fontSize: 24)),
                                          onPressed: () =>
                                              _enterCombatPhase(task.id),
                                          tooltip: "討つ！",
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      // ── 戦術選択バー（下部オーバーレイ） ──
      bottomNavigationBar: isInCombat
          ? CombatSelectionBar(
              onActionSelected: _onActionSelected,
              skillAvailable: _isSkillAvailable(playerVM.player),
              skillUnavailableReason:
                  _skillUnavailableReason(playerVM.player),
            )
          : null,
    );
  }

  /// スキルアクションが使用可能かを判定する。
  /// 装備スキルが1つ以上ある場合にtrue。
  bool _isSkillAvailable(Player player) {
    return player.equippedSkills.isNotEmpty;
  }

  /// スキル未使用時の理由テキスト。
  String? _skillUnavailableReason(Player player) {
    if (player.equippedSkills.isEmpty) {
      return '装備スキルがありません。寺院でスキルを装備してください。';
    }
    return null;
  }
}
