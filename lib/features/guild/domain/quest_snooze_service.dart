import 'package:rpg_todo/domain/models/task.dart';

/// 微睡みの加護（Monk Lv5 / JobSkill.monkSnooze）の純粋ロジック。
///
/// 期限を持つ未完了クエストの期限を1日延ばす「スヌーズ」について、
/// 可否判定・延期後期限の算出・記録の参照・表示文言の組み立てのみを担う。
/// I/O・Hive・Provider・DateTime.now() には一切依存しない（純粋関数のみ）。
class QuestSnoozeService {
  const QuestSnoozeService();

  /// 延期幅（1日）
  static const Duration snoozeDuration = Duration(days: 1);

  /// 期限が無いため微睡めない旨の文言
  static const String noDeadlineMessage = '期限が無いため微睡めません';

  /// 導線ラベル: '微睡みの加護（+1日）'
  String get actionLabel => '微睡みの加護（+1日）';

  /// スヌーズ可能か（期限が存在する未完了クエストのみ true）
  bool canSnooze(Task task) {
    if (task.isCompleted) return false;
    return task.deadline != null;
  }

  /// スヌーズ不可の理由ラベル（可能なら null）: 期限なし→'期限が無いため微睡めません'
  String? blockReason(Task task) {
    if (task.deadline == null) return noDeadlineMessage;
    if (task.isCompleted) return '既に討伐済みのため微睡めません';
    return null;
  }

  /// 延期後の期限（task.deadline が null なら null）。now は使わない純粋計算。
  DateTime? extendedDeadline(Task task) {
    final deadline = task.deadline;
    if (deadline == null) return null;
    return deadline.add(snoozeDuration);
  }

  /// スヌーズ済みか（player.snoozedTasks は `Map<String, DateTime>` taskId→実行日）
  bool isSnoozed(Map<String, DateTime> snoozedTasks, String taskId) {
    return snoozedTasks.containsKey(taskId);
  }

  /// スヌーズ実行日
  DateTime? snoozedAt(Map<String, DateTime> snoozedTasks, String taskId) {
    return snoozedTasks[taskId];
  }

  /// スヌーズ済みクエスト数（tasks に実在するIDのみ数える）
  int countSnoozed(List<Task> tasks, Map<String, DateTime> snoozedTasks) {
    return snoozedTasksOf(tasks, snoozedTasks).length;
  }

  /// スヌーズ済みクエスト一覧（tasks の順序を保持・実在しないIDは無視）
  List<Task> snoozedTasksOf(
    List<Task> tasks,
    Map<String, DateTime> snoozedTasks,
  ) {
    if (snoozedTasks.isEmpty) return <Task>[];
    return tasks.where((task) => snoozedTasks.containsKey(task.id)).toList();
  }

  /// 実行前の確認メッセージ。例: '期限 10/21 21:00 → 10/22 21:00 に延ばしますか？'
  /// 期限が null なら '期限が無いため微睡めません' を返す。日付はゼロ埋めしない M/d HH:mm 形式。
  String confirmMessage(Task task) {
    final extended = extendedDeadline(task);
    if (extended == null) return noDeadlineMessage;
    final before = _dateTimeLabel(task.deadline!);
    final after = _dateTimeLabel(extended);
    return '期限 $before → $after に延ばしますか？';
  }

  /// カード上のバッジ文言。スヌーズされていなければ null。例: '微睡み 10/21'
  String? badgeLabel(Map<String, DateTime> snoozedTasks, String taskId) {
    final at = snoozedTasks[taskId];
    if (at == null) return null;
    return '微睡み ${_monthDayLabel(at)}';
  }

  /// 'M/d HH:mm'（月日はゼロ埋めしない・時分のみ2桁ゼロ埋め）
  String _dateTimeLabel(DateTime d) =>
      '${_monthDayLabel(d)} ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

  /// 'M/d'
  String _monthDayLabel(DateTime d) => '${d.month}/${d.day}';

  /// 2桁ゼロ埋め
  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
