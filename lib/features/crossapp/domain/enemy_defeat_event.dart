/// 敵討伐イベント（契約 v1）の純粋関数群。
///
/// ここには I/O も `DateTime.now()` の呼出も置かない。時刻は呼出側が注入する。
/// スキーマは kozuchi の消費契約に合わせる:
/// `{event: 'enemy_defeated', taskTitle, questRank, baseExp, timestamp}`
library;

import 'dart:convert';

/// クエストランクを契約値（'S' | 'A' | 'B'）へ正規化する。
///
/// trim + 大文字化。許可外・空文字は 'B' に落とす（防御的既定値）。
String normalizeQuestRank(String raw) {
  final normalized = raw.trim().toUpperCase();
  if (normalized == 'S' || normalized == 'A' || normalized == 'B') {
    return normalized;
  }
  return 'B';
}

/// 討伐イベントのマップを契約スキーマ・固定キー順で組み立てる。
///
/// [baseExp] が負の場合は 0 にクランプする。
Map<String, dynamic> buildEnemyDefeatEvent({
  required String taskTitle,
  required String questRank,
  required int baseExp,
  required String timestamp,
}) {
  return <String, dynamic>{
    'event': 'enemy_defeated',
    'taskTitle': taskTitle,
    'questRank': normalizeQuestRank(questRank),
    'baseExp': baseExp < 0 ? 0 : baseExp,
    'timestamp': timestamp,
  };
}

/// イベントを jsonl の1行（改行なしのコンパクトJSON）にエンコードする。
String encodeEventLine(Map<String, dynamic> event) => jsonEncode(event);

/// [now] を UTC の ISO8601 文字列へ整形する。
String formatTimestamp(DateTime now) => now.toUtc().toIso8601String();
