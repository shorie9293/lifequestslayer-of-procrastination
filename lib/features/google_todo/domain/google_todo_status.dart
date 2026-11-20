import 'package:flutter/foundation.dart';

/// Google ToDo 連携の状態（純粋な値オブジェクト）。
///
/// Edge Function `google-todo/status` の応答をそのまま写す。
/// 画面はこの型だけを見て文言を決め、通信の詳細を持たない。
@immutable
class GoogleTodoStatus {
  const GoogleTodoStatus({
    this.linked = false,
    this.email,
    this.listId,
    this.listTitle,
    this.linkedAt,
    this.lastRunAt,
    this.lastOkAt,
    this.lastError,
    this.pulled = 0,
    this.pushed = 0,
  });

  final bool linked;
  final String? email;
  final String? listId;
  final String? listTitle;
  final DateTime? linkedAt;
  final DateTime? lastRunAt;
  final DateTime? lastOkAt;
  final String? lastError;
  final int pulled;
  final int pushed;

  static const GoogleTodoStatus notLinked = GoogleTodoStatus();

  static DateTime? _dt(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  factory GoogleTodoStatus.fromJson(Map<String, dynamic> json) {
    return GoogleTodoStatus(
      linked: json['linked'] == true,
      email: json['email'] as String?,
      listId: json['listId'] as String?,
      listTitle: json['listTitle'] as String?,
      linkedAt: _dt(json['linkedAt']),
      lastRunAt: _dt(json['lastRunAt']),
      lastOkAt: _dt(json['lastOkAt']),
      lastError: json['lastError'] as String?,
      pulled: (json['pulled'] as num?)?.toInt() ?? 0,
      pushed: (json['pushed'] as num?)?.toInt() ?? 0,
    );
  }

  /// 同期結果の一行説明（例: 「3分前に同期・取得2/送信1」）。
  ///
  /// [now] を注入できるようにして、時刻依存の試練を可能にする。
  String describeSync(DateTime now) {
    if (!linked) return '未連携';
    final ok = lastOkAt;
    if (ok == null) {
      if (lastError != null && lastError!.isNotEmpty) {
        return '未同期（前回の失敗: $lastError）';
      }
      return '未同期';
    }
    return '${describeElapsed(now.difference(ok))}に同期・取得$pulled/送信$pushed';
  }

  /// 経過時間の日本語表記（1分未満は「たった今」）。
  static String describeElapsed(Duration d) {
    if (d.inSeconds < 60) return 'たった今';
    if (d.inMinutes < 60) return '${d.inMinutes}分前';
    if (d.inHours < 24) return '${d.inHours}時間前';
    return '${d.inDays}日前';
  }

  GoogleTodoStatus copyWith({
    bool? linked,
    int? pulled,
    int? pushed,
    DateTime? lastOkAt,
    String? lastError,
  }) {
    return GoogleTodoStatus(
      linked: linked ?? this.linked,
      email: email,
      listId: listId,
      listTitle: listTitle,
      linkedAt: linkedAt,
      lastRunAt: lastRunAt,
      lastOkAt: lastOkAt ?? this.lastOkAt,
      lastError: lastError,
      pulled: pulled ?? this.pulled,
      pushed: pushed ?? this.pushed,
    );
  }
}

/// Google のタスクリスト（1つだけ選んで同期する）。
@immutable
class GoogleTodoList {
  const GoogleTodoList({required this.id, required this.title});

  final String id;
  final String title;

  factory GoogleTodoList.fromJson(Map<String, dynamic> json) => GoogleTodoList(
        id: json['id'] as String,
        title: (json['title'] as String?)?.trim().isNotEmpty == true
            ? json['title'] as String
            : '名称未設定',
      );
}

/// 同期実行の結果。
@immutable
class GoogleTodoSyncResult {
  const GoogleTodoSyncResult({
    required this.pulled,
    required this.pushed,
    this.failures = const <String>[],
  });

  final int pulled;
  final int pushed;
  final List<String> failures;

  bool get ok => failures.isEmpty;

  factory GoogleTodoSyncResult.fromJson(Map<String, dynamic> json) {
    return GoogleTodoSyncResult(
      pulled: (json['pulled'] as num?)?.toInt() ?? 0,
      pushed: (json['pushed'] as num?)?.toInt() ?? 0,
      failures: (json['failures'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }

  String get summary => ok ? '取得$pulled件・送信$pushed件' : '一部失敗（${failures.length}件）';
}

/// 同期対象を示す札。クエスト編集の札ダイアログで付与・剥奪する。
const String googleTodoTag = 'GoogleToDo';
