import 'package:rpg_todo/domain/models/task.dart';

/// 札（タグ）の集計結果1件
class QuestTagCount {
  final String tag;
  final int count;
  const QuestTagCount({required this.tag, required this.count});
}

/// 新規タグの検証結果
enum QuestTagValidation { ok, empty, tooLong, duplicate }

/// 札（タグ）の正規化・検証・集計・絞り込み（純粋関数のみ）
class QuestTagService {
  QuestTagService._();

  static const int maxTagLength = 12;

  /// trim → 全角英数字(U+FF01..U+FF5E)と全角スペース(U+3000)を半角へ →
  /// 連続空白を単一化。大文字小文字は保存時にそのまま残す（比較は equalsIgnoreCase）。
  static String normalize(String input) {
    final sb = StringBuffer();
    for (final code in input.trim().runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) {
        sb.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        sb.write(' ');
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 大文字小文字無視の比較キー
  static String _key(String input) => normalize(input).toLowerCase();

  /// 検証。tag 正規化後に空→empty / 13文字以上→tooLong /
  /// 既存タグと大文字小文字無視で一致→duplicate / それ以外→ok
  static QuestTagValidation validateNew(
    String tag,
    Iterable<String> existingTags,
  ) {
    final normalized = normalize(tag);
    if (normalized.isEmpty) return QuestTagValidation.empty;
    if (normalized.runes.length > maxTagLength) {
      return QuestTagValidation.tooLong;
    }
    final key = normalized.toLowerCase();
    for (final existing in existingTags) {
      if (_key(existing) == key) return QuestTagValidation.duplicate;
    }
    return QuestTagValidation.ok;
  }

  /// 重複（大文字小文字無視）を除去して正規化したタグ一覧。順序は初出順。
  static List<String> uniqueTags(Iterable<String> rawTags) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawTags) {
      final normalized = normalize(raw);
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized.toLowerCase())) continue;
      result.add(normalized);
    }
    return result;
  }

  /// 全タスクのタグを集計。件数降順→タグ名昇順（比較は normalize 後、
  /// 同値時は元のタグ文字列昇順）→ それでも同値なら初出index昇順（明示タイブレーク）。
  /// 空白のみ/空文字タグは無視。入力は破壊しない。
  static List<QuestTagCount> counts(List<Task> tasks) {
    final countsByTag = <String, int>{};
    final firstIndex = <String, int>{};
    var order = 0;
    for (final task in tasks) {
      final seenInTask = <String>{};
      for (final raw in List<String>.of(task.tags)) {
        final normalized = normalize(raw);
        if (normalized.isEmpty) continue;
        if (!seenInTask.add(normalized)) continue;
        countsByTag[normalized] = (countsByTag[normalized] ?? 0) + 1;
        firstIndex.putIfAbsent(normalized, () => order++);
      }
    }
    final entries = countsByTag.entries
        .map((e) => QuestTagCount(tag: e.key, count: e.value))
        .toList();
    entries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final byName = normalize(a.tag).compareTo(normalize(b.tag));
      if (byName != 0) return byName;
      final byRaw = a.tag.compareTo(b.tag);
      if (byRaw != 0) return byRaw;
      return firstIndex[a.tag]!.compareTo(firstIndex[b.tag]!);
    });
    return entries;
  }

  /// 指定タグ集合のいずれかを持つか（OR）。selected が空なら true。
  /// 比較は normalize 後の大文字小文字無視の完全一致。
  static bool matchesTags(Task task, Set<String> selectedTags) {
    if (selectedTags.isEmpty) return true;
    final wanted = selectedTags.map(_key).toSet();
    return task.tags.any((tag) => wanted.contains(_key(tag)));
  }

  /// タグで絞り込む（OR）。selected が空なら入力をそのまま返す。
  static List<Task> filterByTags(List<Task> tasks, Set<String> selectedTags) {
    if (selectedTags.isEmpty) return tasks;
    return tasks
        .where((task) => matchesTags(task, selectedTags))
        .toList(growable: false);
  }

  /// タスクのタグを追加した新しいリストを返す（Task を破壊しない）。
  /// 既に同名（大文字小文字無視）があればそのままの内容を返す。
  static List<String> withTag(List<String> current, String tag) {
    final normalized = normalize(tag);
    if (normalized.isEmpty) return List<String>.of(current);
    final key = normalized.toLowerCase();
    if (current.any((existing) => _key(existing) == key)) {
      return List<String>.of(current);
    }
    return List<String>.of(current)..add(normalized);
  }

  /// タグを削除した新しいリスト（大文字小文字無視で一致するものを除去）。
  static List<String> withoutTag(List<String> current, String tag) {
    final key = _key(tag);
    return current.where((existing) => _key(existing) != key).toList();
  }
}
