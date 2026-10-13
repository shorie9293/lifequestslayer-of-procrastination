import 'package:flutter/foundation.dart';

/// タスク1件の見積もり時間と実績時間のペア記録（改善提案 #131）。
///
/// [Task.targetTimeMinutes] は見積もりとして存在するが、実績時間の
/// 記録・比較はどこにもない。本モデルは「見積もり vs 実績」を
/// 不変レコードとして保持し、見積もり精度集計（[EstimateAccuracyService]）
/// とグリフォン見積もり精度レポートの表示に供する。
///
/// 状態・IO・乱数を持たない不変モデル（値等価）。
@immutable
class TaskTimeRecord {
  /// 記録対象のタスク ID。
  final String taskId;

  /// タスク題目（レポート表示用のスナップショット）。
  final String title;

  /// 見積もり時間（分）。
  final int estimatedMinutes;

  /// 実績時間（分）。
  final int actualMinutes;

  /// 記録日時。
  final DateTime recordedAt;

  /// 検証付きコンストラクタ（非const・本体で不変条件を強制する）。
  ///
  /// - [taskId]・[title] が空なら [ArgumentError]。
  /// - [estimatedMinutes]・[actualMinutes] が 0 以下なら [ArgumentError]。
  /// （assert は release で無効になるため本体で検証する）
  factory TaskTimeRecord({
    required String taskId,
    required String title,
    required int estimatedMinutes,
    required int actualMinutes,
    DateTime? recordedAt,
  }) {
    if (taskId.isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', 'must not be empty');
    }
    if (title.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (estimatedMinutes <= 0) {
      throw ArgumentError.value(
        estimatedMinutes,
        'estimatedMinutes',
        'must be positive',
      );
    }
    if (actualMinutes <= 0) {
      throw ArgumentError.value(
        actualMinutes,
        'actualMinutes',
        'must be positive',
      );
    }
    return TaskTimeRecord._(
      taskId: taskId,
      title: title,
      estimatedMinutes: estimatedMinutes,
      actualMinutes: actualMinutes,
      recordedAt: recordedAt ?? DateTime.now(),
    );
  }

  const TaskTimeRecord._({
    required this.taskId,
    required this.title,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.recordedAt,
  });

  /// 記録の一意識別子（taskId と記録時刻の組）。
  String get id => '${taskId}_${recordedAt.microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'title': title,
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'recordedAt': recordedAt.toIso8601String(),
      };

  /// JSON から復元する。破損（キー欠落・型不一致・日時不正）は
  /// [FormatException] を投げ、呼出側（リポジトリ）が読み飛ばせるようにする。
  factory TaskTimeRecord.fromJson(Map<String, dynamic> json) {
    final rawTaskId = json['taskId'];
    final rawTitle = json['title'];
    final rawEstimated = json['estimatedMinutes'];
    final rawActual = json['actualMinutes'];
    final rawRecordedAt = json['recordedAt'];
    if (rawTaskId is! String ||
        rawTitle is! String ||
        rawEstimated is! int ||
        rawActual is! int ||
        rawRecordedAt is! String) {
      throw const FormatException('task time record json is malformed');
    }
    final recordedAt = DateTime.tryParse(rawRecordedAt);
    if (recordedAt == null) {
      throw const FormatException('task time record json is malformed');
    }
    return TaskTimeRecord(
      taskId: rawTaskId,
      title: rawTitle,
      estimatedMinutes: rawEstimated,
      actualMinutes: rawActual,
      recordedAt: recordedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskTimeRecord &&
      other.taskId == taskId &&
      other.title == title &&
      other.estimatedMinutes == estimatedMinutes &&
      other.actualMinutes == actualMinutes &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(
        taskId,
        title,
        estimatedMinutes,
        actualMinutes,
        recordedAt,
      );

  @override
  String toString() =>
      'TaskTimeRecord($id, est=$estimatedMinutes, act=$actualMinutes)';
}
