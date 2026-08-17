import 'package:rpg_todo/domain/models/task.dart';

/// 討伐結果の判定と残サブタスク集計を担う純粋関数群（UX-3）。
///
/// 討伐の成否判定（[isVictory]）と、未完了サブタスクの数（[remainingCount]）・
/// 一覧（[incompleteSubTasks]）を提供する。外部依存を持たないため単体試練可能。
class DefeatSummary {
  const DefeatSummary._();

  /// 全サブタスクが完了（またはサブタスクなし）であれば討伐成功。
  static bool isVictory(Task task) => task.subTasks.every((s) => s.isCompleted);

  /// 残り（未完了）サブタスクの数。
  static int remainingCount(Task task) =>
      task.subTasks.where((s) => !s.isCompleted).length;

  /// 未完了サブタスクの一覧（元の順序を保持）。
  static List<SubTask> incompleteSubTasks(Task task) =>
      task.subTasks.where((s) => !s.isCompleted).toList();
}
