// コード適応神書 — 原則④ AppKeys体系
// 全画面の試練用Keyを一括管理
//
// 使い方:
//   試練側: find.byKey(AppKeys.guildFab)
//   コード側: FloatingActionButton(key: AppKeys.guildFab, ...)

import 'package:flutter/material.dart';

class AppKeys {
  AppKeys._();

  // ━━━ ギルド（冒険者依頼所） ━━━
  static const Key guildScreen = Key('screen_guild');
  static const Key guildFab = Key('fab_add_task');
  static const Key guildQuestList = Key('list_quests');
  static const Key guildEmptyState = Key('empty_no_quests');
  static const Key guildRefreshIndicator = Key('refresh_quests');

  // ━━━ タスクカード ━━━
  static const Key taskCard = Key('card_task');
  static const Key taskCardCheck = Key('btn_complete_task');
  static const Key taskCardDelete = Key('btn_delete_task');
  static const Key taskCardTitle = Key('txt_task_title');

  // ━━━ チュートリアル ━━━
  static const Key tutorialOverlay = Key('overlay_tutorial');
  static const Key tutorialUnderstood = Key('btn_understood');
  static const Key tutorialSkip = Key('btn_skip_tutorial');
  static const Key tutorialReward = Key('btn_reward_accept');

  // ━━━ タスク作成フォーム ━━━
  static const Key formTaskDialog = Key('dlg_create_task');
  static const Key formTaskTitle = Key('txt_task_title');
  static const Key formTaskDetail = Key('txt_task_detail');
  static const Key formTaskSubmit = Key('btn_submit_task');
  static const Key formTaskCancel = Key('btn_cancel_task');

  // ━━━ メインタブバー ━━━
  static const Key tabBar = Key('tab_main');
  static const Key tabGuild = Key('tab_guild');
  static const Key tabBattle = Key('tab_battle');
  static const Key tabTemple = Key('tab_temple');
  static const Key tabTown = Key('tab_town');

  // ━━━ 戦場 ━━━
  static const Key battleScreen = Key('screen_battle');
  static const Key battleComplete = Key('btn_battle_complete');

  // ━━━ 神殿 ━━━
  static const Key templeScreen = Key('screen_temple');

  // ━━━ 街 ━━━
  static const Key townScreen = Key('screen_town');

  // ━━━ 汎用 ━━━
  static const Key backButton = Key('btn_back');
  static const Key closeButton = Key('btn_close');
  static const Key confirmDialog = Key('dlg_confirm');
  static const Key helpButton = Key('btn_help');
  static const Key settingsButton = Key('btn_settings');
}
