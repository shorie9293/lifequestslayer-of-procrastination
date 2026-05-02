// コード適応神書 — 原則④ AppKeys体系
// 全画面の試練用Keyを一括管理
//
// 使い方:
//   試練側: find.byKey(AppKeys.guildFab)
//   コード側: FloatingActionButton(key: AppKeys.guildFab, ...)
//
// 制定: 令和八年皐月三日（適1で基本定義、適2で拡張＋全紐付け）

import 'package:flutter/material.dart';

class AppKeys {
  AppKeys._();

  // ━━━ ギルド（冒険者依頼所） ━━━
  static const Key guildScreen = Key('screen_guild');
  static const Key guildFab = Key('fab_add_task');
  static const Key guildQuestList = Key('list_quests');
  static const Key guildEmptyState = Key('empty_no_quests');
  static const Key guildRefreshIndicator = Key('refresh_quests');
  static const Key guildRecurringTasksDialog = Key('dlg_recurring_tasks');
  static const Key guildSettingsMenu = Key('menu_settings');
  static const Key guildKnowledgeQuestToggle = Key('tgl_knowledge_quest');

  // ━━━ タスクカード ━━━
  static const Key taskCard = Key('card_task');
  static const Key taskCardCheck = Key('btn_complete_task');
  static const Key taskCardDelete = Key('btn_delete_task');
  static const Key taskCardTitle = Key('txt_task_title');
  static const Key taskCardAccept = Key('btn_accept_task');
  static const Key taskCardEdit = Key('btn_edit_task');

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

  // ━━━ 戦場（ホーム） ━━━
  static const Key battleScreen = Key('screen_battle');
  static const Key battleComplete = Key('btn_battle_complete');
  static const Key battleCancel = Key('btn_battle_cancel');
  static const Key battleActiveTaskList = Key('list_active_tasks');
  static const Key battleEmptyState = Key('empty_no_battles');
  static const Key battleLevelUpDialog = Key('dlg_level_up');

  // ━━━ 神殿（転職） ━━━
  static const Key templeScreen = Key('screen_temple');
  static const Key templeJobCardAdventurer = Key('card_job_adventurer');
  static const Key templeJobCardWarrior = Key('card_job_warrior');
  static const Key templeJobCardCleric = Key('card_job_cleric');
  static const Key templeJobCardWizard = Key('card_job_wizard');
  static const Key templeSkillToggle = Key('tgl_skill_inherit');

  // ━━━ 街 ━━━
  static const Key townScreen = Key('screen_town');
  static const Key townCoinBalance = Key('txt_coin_balance');
  static const Key townGemBalance = Key('txt_gem_balance');
  static const Key townGemShopButton = Key('btn_gem_shop');
  static const Key townInnSection = Key('sec_inn');
  static const Key townTitleSection = Key('sec_titles');
  static const Key townShopHomeSection = Key('sec_shop_home');
  static const Key townSkinShopSection = Key('sec_shop_skins');
  static const Key townBuyConfirmDialog = Key('dlg_buy_confirm');
  static const Key townInnConfirmDialog = Key('dlg_inn_confirm');
  static const Key townTitleSelectDialog = Key('dlg_title_select');
  static const Key townUnequipButton = Key('btn_unequip_skin');

  // ━━━ 宝石ショップ ━━━
  static const Key gemShopScreen = Key('screen_gem_shop');
  static const Key gemShopBackButton = Key('btn_gem_shop_back');
  static const Key gemShopExchangeCoin = Key('btn_exchange_coin');
  static const Key gemShopResetFatigue = Key('btn_reset_fatigue');
  static const Key gemShopPurchaseConfirm = Key('dlg_purchase_confirm');
  static const Key gemShopUseConfirm = Key('dlg_use_confirm');

  // ━━━ プレイヤーステータスヘッダー ━━━
  static const Key playerStatusHeader = Key('header_player_status');

  // ━━━ ダイアログ類 ━━━
  static const Key helpDialog = Key('dlg_help');
  static const Key knowledgeQuestDialog = Key('dlg_knowledge_quest');
  static const Key fatigueGemPopup = Key('dlg_fatigue_gem');
  static const Key notificationSettingsDialog = Key('dlg_notification_settings');

  // ━━━ 汎用 ━━━
  static const Key backButton = Key('btn_back');
  static const Key closeButton = Key('btn_close');
  static const Key confirmDialog = Key('dlg_confirm');
  static const Key helpButton = Key('btn_help');
  static const Key settingsButton = Key('btn_settings');
  static const Key deleteButton = Key('btn_delete');
}
