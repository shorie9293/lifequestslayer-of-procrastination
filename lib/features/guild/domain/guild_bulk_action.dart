// 寄合所のクエスト一括操作（改善提案 #91）
//
// 選択した複数クエストに対して 出発（受注）/ 延期 / 破棄 をまとめて適用する。
// ロジックは全てこの純粋層に置き、ViewModel と UI は薄く配線するのみ。

import 'package:rpg_todo/domain/models/task.dart';

/// 一括操作の種類
enum GuildBulkAction {
  accept('出発'),
  postpone('延期'),
  delete('破棄');

  const GuildBulkAction(this.label);
  final String label;

  /// 永続化キー等からの復元（未知は null）
  static GuildBulkAction? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final a in values) {
      if (a.name == key) return a;
    }
    return null;
  }
}

/// 一括操作の適用計画（不変）
class GuildBulkActionPlan {
  const GuildBulkActionPlan({
    required this.action,
    required this.targetIds,
    required this.skippedIds,
  });

  final GuildBulkAction action;

  /// 実行対象となるクエストID（クエスト実在かつ選択対象）
  final List<String> targetIds;

  /// 実行対象外となったID（存在しない・未受注でない・完了済み）
  final List<String> skippedIds;

  bool get isEmpty => targetIds.isEmpty;

  /// スナックバー等に表示する要約ラベル
  String get label {
    if (isEmpty) return '対象のクエストがありません';
    return '${action.label}：${targetIds.length}件';
  }
}

/// 一括操作の純粋ロジック
abstract final class GuildBulkActionService {
  /// 一括操作の選択対象になり得るクエスト（未受注かつ未完了）
  static List<Task> selectableTasks(List<Task> tasks) {
    return tasks
        .where((t) => t.status == TaskStatus.inGuild && !t.isCompleted)
        .toList(growable: false);
  }

  /// 選択ID集合と操作から適用計画を作る。
  /// 存在しないIDや対象外（受注済み等）のIDは skippedIds に退ける。
  static GuildBulkActionPlan buildPlan(
    List<Task> tasks,
    Iterable<String> selectedIds,
    GuildBulkAction action,
  ) {
    final byId = {for (final t in tasks) t.id: t};
    final targets = <String>[];
    final skipped = <String>[];
    for (final id in selectedIds) {
      final t = byId[id];
      final selectable = t != null &&
          t.status == TaskStatus.inGuild &&
          !t.isCompleted;
      if (selectable) {
        targets.add(id);
      } else {
        skipped.add(id);
      }
    }
    // 宣言順（画面上の選択順）を安定させるため元ID順で整列
    targets.sort();
    return GuildBulkActionPlan(
      action: action,
      targetIds: targets,
      skippedIds: skipped,
    );
  }

  /// 延期後の期限。既存期限があればそこから、無ければ基準時刻から N 日後。
  /// days は正の整数のみ（0以下は ArgumentError）。
  static DateTime postponedDeadline(Task task, int days, DateTime now) {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', '延期日数は1日以上であること');
    }
    final base = task.deadline ?? now;
    return base.add(Duration(days: days));
  }
}
