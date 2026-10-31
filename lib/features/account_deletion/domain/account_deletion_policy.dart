/// アカウント削除（退会）の判断を司る純粋 Dart の政策。
///
/// Flutter へ依存させない（試練が widget 層抜きで高速に回せるようにするため）。
library;

/// 削除可否・確認文字・削除対象の定義。
class AccountDeletionPolicy {
  const AccountDeletionPolicy();

  /// 確認入力に要求する語（trim 後の完全一致のみ許可）。
  static const String confirmationPhrase = '削除';

  /// 削除対象 Hive box 名（lib 内で実在を確認したもののみ列挙）。
  ///
  /// player_repository: playerBox / task_repository: tasksBox /
  /// settings_repository: settingsBox / reminder_repository: reminderBox /
  /// notification_settings_repository: notification_settings /
  /// battle_record_repository: battle_records /
  /// practice_log_repository: practice_logs /
  /// reflection_repository: reflectionsBox・reflections /
  /// town_view_model: townBox / gryphon_report_repository: gryphon_reports /
  /// hive_quiet_hours_repository: quiet_hours_box /
  /// reduce_motion_repository: reduce_motion_box /
  /// task_time_record_repository: task_time_records /
  /// task_template_repository: task_templates /
  /// streak_freeze_repository: streak_freeze_box /
  /// cross_app_settings_repository: crossAppSettings /
  /// feature_flags: featureFlagsBox
  static const List<String> targetBoxNames = <String>[
    'playerBox',
    'tasksBox',
    'settingsBox',
    'reminderBox',
    'notification_settings',
    'battle_records',
    'practice_logs',
    'reflectionsBox',
    'reflections',
    'townBox',
    'gryphon_reports',
    'quiet_hours_box',
    'reduce_motion_box',
    'task_time_records',
    'task_templates',
    'streak_freeze_box',
    'crossAppSettings',
    'featureFlagsBox',
  ];

  /// 画面に列挙する「何が消えるか」の利用者向けラベル。
  static const List<String> targetLabels = <String>[
    '冒険者（プレイヤー）データ',
    'クエスト（タスク）と下書き',
    'アプリ設定・文字サイズ・テーマ',
    'リマインダー・通知設定',
    '戦闘記録',
    '修練ログ（習慣）',
    '振り返りログ・内省バッジ',
    '町・グリフォン報告',
    '連続記録お休み券',
    'その他端末内のすべての保存データ',
  ];

  /// 削除を許してよいか。有効なセッションが無ければ不可。
  bool canDelete({required bool hasActiveSession}) => hasActiveSession;

  /// 「何が消えるか」の列挙文。空なら削除対象なしと明示する。
  String summary(List<String> labels) {
    if (labels.isEmpty) {
      return '削除対象のデータはありません。';
    }
    final buffer = StringBuffer('以下がすべて削除されます。\n');
    for (final label in labels) {
      buffer.writeln('・$label');
    }
    buffer.write('この操作は取り消せません。');
    return buffer.toString();
  }

  /// 確認文字が満たされているか（trim 後の完全一致）。
  bool isConfirmationSatisfied({
    required String input,
    required String expected,
  }) =>
      input.trim() == expected.trim() && expected.trim().isNotEmpty;
}
