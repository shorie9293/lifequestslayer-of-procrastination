/// JSONL 共有イベントログの保持（剪定）計画 — 純粋層。
///
/// 背景（実測）: 共有イベントログは 5 現世が**追記専用**で書き、捨てる工程が
/// 無かった。消費側は起動のたびに `readString` でファイル全体を読み、全行を
/// JSON 解析してから処理済み ID で除外していた＝**起動コストが履歴長に比例**。
///
/// 本クラスは「どの行を残すか」だけを決める。I/O も時刻も持たない。
///
/// ## 不変条件（試練で撃つ契約）
/// 1. **未処理（未消費）行は絶対に落とさない** — 落とすのは処理済み行のみ。
/// 2. **他現世が行数を数えているイベント種別は落とさない** —
///    [preservedEventTypes] に載った種別は、処理済みでも保持する
///    （例: kozuchi は `tsundoku_reward_events.jsonl` の `book_completed` 行を
///    数えて実績判定する。落とすと実績が静かに減る）。
/// 3. **絶対に throw しない** — 壊れた行・空行・型不正があっても計画を返す。
/// 4. 壊れた行は診断用に**直近 [maxRetainedCorrupt] 行だけ**残す。
/// 5. 空行・空白のみの行は常に捨てる（情報を持たない）。
/// 6. 出力は「元の順序」を保つ（追記順＝時系列を壊さない）。
library;

import 'dart:convert';

/// 剪定計画。
class JsonlRetentionPlan {
  const JsonlRetentionPlan({
    required this.retainedLines,
    required this.droppedConsumed,
    required this.droppedCorrupt,
    required this.droppedEmpty,
    required this.pendingCount,
    required this.preservedCount,
  });

  /// 残す行（元の順序）。
  final List<String> retainedLines;

  /// 捨てた処理済み行数。
  final int droppedConsumed;

  /// 捨てた壊れ行数（上限超過分）。
  final int droppedCorrupt;

  /// 捨てた空行数。
  final int droppedEmpty;

  /// 残す行のうち未処理の数。
  final int pendingCount;

  /// 残す行のうち「他現世が数えるため保持した」処理済み行の数。
  final int preservedCount;

  /// 次回走査で JSON 解析する行数（＝保持行数）。
  int get parseLineCount => retainedLines.length;

  /// 何か捨てたか（false なら書き戻し不要＝無駄な SAF 書込をしない）。
  bool get shouldRewrite =>
      droppedConsumed > 0 || droppedCorrupt > 0 || droppedEmpty > 0;

  /// 書き戻す本文。0 行なら空文字（空ファイル）。
  String get content =>
      retainedLines.isEmpty ? '' : '${retainedLines.join('\n')}\n';

  @override
  String toString() => 'JsonlRetentionPlan(keep=${retainedLines.length}, '
      'pending=$pendingCount, preserved=$preservedCount, '
      'consumed=$droppedConsumed, corrupt=$droppedCorrupt, '
      'empty=$droppedEmpty)';
}

/// [JsonlRetentionPlan] を組み立てる純粋関数。
///
/// [consumedIds] は「処理済み event_id の集合」。
/// [preservedEventTypes] は「処理済みでも落とさない event_type」。
/// [maxRetainedCorrupt] は診断用に残す壊れ行の上限（既定 10）。
JsonlRetentionPlan buildJsonlRetentionPlan(
  List<String> lines, {
  required Set<String> consumedIds,
  Set<String> preservedEventTypes = const <String>{},
  int maxRetainedCorrupt = 10,
}) {
  final safeMaxCorrupt = maxRetainedCorrupt < 0 ? 0 : maxRetainedCorrupt;

  final retained = <String>[];
  final corruptLines = <String>[];
  var droppedConsumed = 0;
  var droppedEmpty = 0;
  var pendingCount = 0;
  var preservedCount = 0;

  for (final line in lines) {
    if (line.trim().isEmpty) {
      droppedEmpty++;
      continue;
    }

    final parsed = _tryParseLine(line);
    if (parsed == null) {
      corruptLines.add(line);
      continue;
    }

    if (!consumedIds.contains(parsed.id)) {
      retained.add(line);
      pendingCount++;
      continue;
    }

    // 処理済み。ただし他現世が数える種別は保持する。
    if (parsed.eventType != null &&
        preservedEventTypes.contains(parsed.eventType)) {
      retained.add(line);
      preservedCount++;
      continue;
    }

    droppedConsumed++;
  }

  // 壊れ行は直近 N 件だけ残す（古いものから捨てる）。
  final keptCorrupt = corruptLines.length <= safeMaxCorrupt
      ? corruptLines
      : corruptLines.sublist(corruptLines.length - safeMaxCorrupt);
  final droppedCorrupt = corruptLines.length - keptCorrupt.length;

  return JsonlRetentionPlan(
    retainedLines: <String>[...retained, ...keptCorrupt],
    droppedConsumed: droppedConsumed,
    droppedCorrupt: droppedCorrupt,
    droppedEmpty: droppedEmpty,
    pendingCount: pendingCount,
    preservedCount: preservedCount,
  );
}

class _ParsedLine {
  const _ParsedLine(this.id, this.eventType);

  final String id;
  final String? eventType;
}

/// 行から `event_id` / `event_type` を取り出す。解釈できなければ null。
_ParsedLine? _tryParseLine(String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map) return null;
    final id = decoded['event_id'];
    if (id is! String || id.isEmpty) return null;
    final type = decoded['event_type'];
    return _ParsedLine(id, type is String ? type : null);
  } on Object {
    return null;
  }
}
