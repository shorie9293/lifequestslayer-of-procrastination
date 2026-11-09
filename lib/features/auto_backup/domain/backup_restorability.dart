import 'dart:convert';

import 'package:rpg_todo/domain/services/full_backup.dart';

/// 控え1件の復元可否。
enum BackupRestoreState {
  /// 復元できる。
  restorable,

  /// 控えが空（null・空文字・空白のみ）。
  empty,

  /// JSON として読めない、または復元形式に合わない。
  corrupt,

  /// 版番号が無い／不正で、この版では復元できない。
  unsupportedVersion,
}

/// 控えの復元可否を表す値オブジェクト。
///
/// [classify] は**絶対に例外を投げない**。一覧表示・復元実行前の双方で
/// 同じ判定を使い、「復元ボタンは出るのに押すと失敗する」不整合を断つ。
class BackupRestorability {
  const BackupRestorability(this.state, this.reason);

  final BackupRestoreState state;

  /// 利用者向けの理由文（日本語）。
  final String reason;

  bool get isRestorable => state == BackupRestoreState.restorable;

  /// 一覧に出す短いラベル。
  String get label {
    switch (state) {
      case BackupRestoreState.restorable:
        return '復元可能';
      case BackupRestoreState.empty:
        return '空です';
      case BackupRestoreState.corrupt:
        return 'JSONが壊れています';
      case BackupRestoreState.unsupportedVersion:
        return '版番号が無い控えです';
    }
  }

  /// 控え本文を分類する。例外は投げず、必ず4状態のいずれかを返す。
  static BackupRestorability classify(String? json) {
    if (json == null || json.trim().isEmpty) {
      return const BackupRestorability(
        BackupRestoreState.empty,
        '控えが空です',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return const BackupRestorability(
        BackupRestoreState.corrupt,
        'JSONとして読めません',
      );
    }

    if (decoded is! Map) {
      return const BackupRestorability(
        BackupRestoreState.corrupt,
        'JSONの中身がオブジェクトではありません',
      );
    }

    final version = decoded['version'];
    if (version is! int || version < 1) {
      return const BackupRestorability(
        BackupRestoreState.unsupportedVersion,
        '版番号が無い控えはこの版では復元できません',
      );
    }

    FullBackupData? data;
    try {
      data = FullBackupService().decode(json);
    } catch (_) {
      data = null;
    }
    if (data == null) {
      return const BackupRestorability(
        BackupRestoreState.corrupt,
        '中身が復元形式に合いません',
      );
    }

    return const BackupRestorability(
      BackupRestoreState.restorable,
      '復元できます',
    );
  }
}
