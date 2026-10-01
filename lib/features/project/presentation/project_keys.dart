// コード適応神書 原則④ AppKeys体系 — 計画の陣（プロジェクト機能）
//
// 使い方:
//   試練側: find.byKey(ProjectAppKeys.projectScreen)
//   コード側: Scaffold(key: ProjectAppKeys.projectScreen, ...)
//
// kozuchi の CategoryBudgetAppKeys / CalendarAppKeys と同じ前例。

import 'package:flutter/material.dart';

class ProjectAppKeys {
  ProjectAppKeys._();

  // ━━━ 画面 ━━━
  static const Key projectScreen = Key('screen_project');
  static const Key projectList = Key('list_projects');
  static const Key projectEmptyState = Key('empty_no_projects');

  // ━━━ 作成ダイアログ ━━━
  static const Key projectCreateFab = Key('fab_create_project');
  static const Key projectCreateDialog = Key('dlg_create_project');
  static const Key projectNameField = Key('txt_project_name');
  static const Key projectBonusField = Key('txt_project_bonus');
  static const Key projectSubmit = Key('btn_project_submit');
  static const Key projectCancel = Key('btn_project_cancel');

  // ━━━ 行（index ベース。重複禁止のため index は一覧の並び順） ━━━
  static Key projectRow(int index) => Key('card_project_$index');
  static Key projectMenu(int index) => Key('btn_project_menu_$index');

  // ━━━ 編集ダイアログ ━━━
  static const Key projectEditDialog = Key('dlg_edit_project');
  static const Key projectEditSubmit = Key('btn_project_edit_submit');

  // ━━━ 削除確認ダイアログ ━━━
  static const Key projectDeleteDialog = Key('dlg_delete_project');
  static const Key projectDeleteConfirm = Key('btn_project_delete_confirm');
  static const Key projectDeleteCancel = Key('btn_project_delete_cancel');

  // ━━━ 詳細（割り当て）ボトムシート ━━━
  static const Key projectDetailSheet = Key('sheet_project_detail');
  static Key assignButton(String taskId) => Key('btn_assign_${taskId}');
  static Key unassignButton(String taskId) => Key('btn_unassign_${taskId}');
}