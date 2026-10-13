import 'package:flutter/foundation.dart';

/// 見積もり精度レポート（改善提案 #131）の試練用 Key 一式。
///
/// 既存 [AppKeys] には追記せず、本機能専用ファイルに分離する。
class EstimateAccuracyKeys {
  const EstimateAccuracyKeys._();

  /// レポート画面（Scaffold）。
  static const Key screen = Key('estimate_accuracy_screen');

  /// サマリーカード。
  static const Key summaryCard = Key('estimate_accuracy_summary_card');

  /// 0件のときの空状態。
  static const Key emptyState = Key('estimate_accuracy_empty_state');

  /// 「実績を記録」FAB。
  static const Key addButton = Key('estimate_accuracy_add_button');

  /// 記録行のリスト。
  static const Key list = Key('estimate_accuracy_list');

  /// 記録追加ダイアログ。
  static const Key dialog = Key('estimate_accuracy_dialog');

  /// クエスト選択ドロップダウン。
  static const Key taskField = Key('estimate_accuracy_task_field');

  /// 見積もり分 TextField。
  static const Key estimatedField = Key('estimate_accuracy_estimated_field');

  /// 実績分 TextField。
  static const Key actualField = Key('estimate_accuracy_actual_field');

  /// 保存ボタン。
  static const Key saveButton = Key('estimate_accuracy_save_button');

  /// キャンセルボタン。
  static const Key cancelButton = Key('estimate_accuracy_cancel_button');

  /// 寄合所オーバーフローメニューの入口項目。
  static const Key guildEntry = Key('estimate_accuracy_guild_entry');

  /// サマリーの的中率ラベル。
  static const Key summaryOnTargetRate =
      Key('estimate_accuracy_summary_on_target_rate');

  /// サマリーの平均誤差ラベル。
  static const Key summaryAverageError =
      Key('estimate_accuracy_summary_average_error');

  /// 記録行の Key。
  static Key recordRow(String id) => Key('estimate_accuracy_row_$id');

  /// 記録行の削除ボタン Key。
  static Key deleteButton(String id) => Key('estimate_accuracy_delete_$id');
}
