/// 現世（アプリ）をまたぐ受け渡しの「最後の送信／受信」を表す**純粋な状態**。
///
/// 判定材料と表示材料は**この1つの型**から取る（#209 の原則:
/// 可否を判定する側と、実際に表示する側で真実源を分けるな）。
/// Flutter に依存しないため、試練でそのまま撃てる。
library;

import 'dart:convert';

/// 1回の送信または受信の記録。
class CrossAppTransferRecord {
  const CrossAppTransferRecord({
    required this.at,
    required this.ok,
    required this.count,
    this.fileName,
    this.error,
  });

  /// 記録時刻。
  final DateTime at;

  /// 成否。false なら [error] に理由が入る。
  final bool ok;

  /// 送受信した件数（失敗時は 0 が既定）。
  final int count;

  /// 対象ファイル名（[SharedCrossAppFiles] の契約名）。不明なら null。
  final String? fileName;

  /// 失敗理由（成功時は null）。
  final String? error;

  Map<String, Object?> toJson() => <String, Object?>{
        'at': at.toIso8601String(),
        'ok': ok,
        'count': count,
        if (fileName != null) 'file': fileName,
        if (error != null) 'error': error,
      };

  /// 壊れた JSON でも**例外を投げない**。読めなければ null。
  static CrossAppTransferRecord? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final atRaw = json['at'];
    if (atRaw is! String) return null;
    final at = DateTime.tryParse(atRaw);
    if (at == null) return null;
    final okRaw = json['ok'];
    final countRaw = json['count'];
    final fileRaw = json['file'];
    final errorRaw = json['error'];
    return CrossAppTransferRecord(
      at: at,
      ok: okRaw == true,
      count:
          countRaw is int ? countRaw : (countRaw is num ? countRaw.toInt() : 0),
      fileName: fileRaw is String && fileRaw.isNotEmpty ? fileRaw : null,
      error: errorRaw is String && errorRaw.isNotEmpty ? errorRaw : null,
    );
  }
}

/// 連携の現在の状態（最後の送信・最後の受信・共有フォルダの可否）。
class CrossAppLinkSnapshot {
  const CrossAppLinkSnapshot({
    this.lastSent,
    this.lastReceived,
    this.sharedFolderReady = false,
  });

  final CrossAppTransferRecord? lastSent;
  final CrossAppTransferRecord? lastReceived;
  final bool sharedFolderReady;

  static const CrossAppLinkSnapshot empty = CrossAppLinkSnapshot();

  CrossAppLinkSnapshot copyWith({
    CrossAppTransferRecord? lastSent,
    CrossAppTransferRecord? lastReceived,
    bool? sharedFolderReady,
  }) =>
      CrossAppLinkSnapshot(
        lastSent: lastSent ?? this.lastSent,
        lastReceived: lastReceived ?? this.lastReceived,
        sharedFolderReady: sharedFolderReady ?? this.sharedFolderReady,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'sharedFolderReady': sharedFolderReady,
        if (lastSent != null) 'lastSent': lastSent!.toJson(),
        if (lastReceived != null) 'lastReceived': lastReceived!.toJson(),
      };

  String encode() => jsonEncode(toJson());

  /// 壊れた保存値でも**例外を投げない**（破損は日常的に起こる）。
  static CrossAppLinkSnapshot decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return empty;
      return CrossAppLinkSnapshot(
        sharedFolderReady: decoded['sharedFolderReady'] == true,
        lastSent: CrossAppTransferRecord.tryFromJson(decoded['lastSent']),
        lastReceived:
            CrossAppTransferRecord.tryFromJson(decoded['lastReceived']),
      );
    } on Object {
      return empty;
    }
  }
}

/// 表示文言（純粋・画面がそのまま出す）。
class CrossAppLinkStatusText {
  const CrossAppLinkStatusText._();

  /// `2026/11/11 09:12` 形式。null は「未記録」。
  static String time(DateTime? at) {
    if (at == null) return '未記録';
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// 「成功」「失敗」「未記録」。
  static String outcome(CrossAppTransferRecord? record) {
    if (record == null) return '未記録';
    return record.ok ? '成功' : '失敗';
  }

  /// 1行表示: `成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl`
  static String row(CrossAppTransferRecord? record) {
    if (record == null) return '未記録';
    final parts = <String>[
      outcome(record),
      time(record.at),
      '${record.count}件',
    ];
    final name = record.fileName;
    if (name != null && name.isNotEmpty) parts.add(name);
    return parts.join('・');
  }

  /// 共有フォルダの状態。
  static String folder(bool ready) => ready ? '設定済み' : '未設定（連携は停止中）';

  /// 失敗理由（成功・未記録なら空文字）。長すぎる場合は切り詰める。
  static String detail(CrossAppTransferRecord? record) {
    final error = record?.error;
    if (error == null || error.isEmpty) return '';
    if (error.length <= 160) return error;
    return '${error.substring(0, 160)}…';
  }

  /// 受け取った内容の件数（JSONL は行数、単一 JSON は 1 行）。
  static int countLines(String? content) {
    if (content == null) return 0;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split('\n').length;
  }
}
