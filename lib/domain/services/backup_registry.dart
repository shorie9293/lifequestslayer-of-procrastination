/// バックアップ対象 Hive box の許可リスト（純粋 Dart・Hive 非依存）。
///
/// 許可リスト方式: ここに列挙された box のみ capture / restore の対象とする。
/// 未知 box は capture せず、restore もしない。
enum BackupBoxKind {
  /// 値は JSON 直列化可能（String/num/bool/null/List/Map）
  jsonValue,

  /// 値は Reflection オブジェクト
  reflectionObject,
}

/// バックアップ対象 box 1件分の仕様。
class BackupBoxSpec {
  final String boxName;

  final BackupBoxKind kind;

  /// 日本語ラベル（UI表示用）
  final String label;

  const BackupBoxSpec({
    required this.boxName,
    required this.kind,
    required this.label,
  });
}

/// バックアップ対象 box の registry。
class BackupBoxRegistry {
  /// playerBox / tasksBox は player / tasks キーで別途退避済みのため除外。
  /// playerBox_backup / tasksBox_backup は内部自動退避用のため除外。
  /// featureFlagsBox / iapPendingBox は端末固有・課金一時状態のため除外。
  static const List<BackupBoxSpec> specs = [
    BackupBoxSpec(
      boxName: 'battle_records',
      kind: BackupBoxKind.jsonValue,
      label: '討伐戦績',
    ),
    BackupBoxSpec(
      boxName: 'practice_logs',
      kind: BackupBoxKind.jsonValue,
      label: '勤行ログ',
    ),
    BackupBoxSpec(
      boxName: 'task_time_records',
      kind: BackupBoxKind.jsonValue,
      label: '見積もり/実績',
    ),
    BackupBoxSpec(
      boxName: 'task_templates',
      kind: BackupBoxKind.jsonValue,
      label: 'クエスト雛形',
    ),
    BackupBoxSpec(
      boxName: 'reminderBox',
      kind: BackupBoxKind.jsonValue,
      label: 'リマインダー',
    ),
    BackupBoxSpec(
      boxName: 'gryphon_reports',
      kind: BackupBoxKind.jsonValue,
      label: '週次グリフォン報告',
    ),
    BackupBoxSpec(
      boxName: 'settingsBox',
      kind: BackupBoxKind.jsonValue,
      label: '各種設定',
    ),
    BackupBoxSpec(
      boxName: 'notification_settings',
      kind: BackupBoxKind.jsonValue,
      label: '通知設定',
    ),
    BackupBoxSpec(
      boxName: 'crossAppSettings',
      kind: BackupBoxKind.jsonValue,
      label: 'クロスアプリ設定',
    ),
    BackupBoxSpec(
      boxName: 'tutorialBox',
      kind: BackupBoxKind.jsonValue,
      label: 'チュートリアル状態',
    ),
    BackupBoxSpec(
      boxName: 'townBox',
      kind: BackupBoxKind.jsonValue,
      label: '町の状態',
    ),
    BackupBoxSpec(
      boxName: 'reflections',
      kind: BackupBoxKind.reflectionObject,
      label: '内省ログ',
    ),
    BackupBoxSpec(
      boxName: 'reflectionsBox',
      kind: BackupBoxKind.reflectionObject,
      label: '内省ログ(別領域)',
    ),
  ];

  /// 対象 box 数。
  static int get count => specs.length;

  /// 対象 box 名の一覧。
  static List<String> get boxNames =>
      specs.map((s) => s.boxName).toList(growable: false);

  /// boxName に対応する spec。未知なら null。
  static BackupBoxSpec? specFor(String boxName) {
    for (final spec in specs) {
      if (spec.boxName == boxName) return spec;
    }
    return null;
  }

  /// boxName がバックアップ対象か。
  static bool isBackupTarget(String boxName) => specFor(boxName) != null;
}
