// 検索語の履歴（純粋 Dart・Flutter 非依存）。
//
// - 新しい順・最大 8 件。
// - add は空白を正規化し、空語は積まない。
// - 大文字小文字を区別せず重複を排除し、表記は新しい入力で置き換える。
// - decode は絶対に例外を投げない（壊れた値は空の履歴へ静かに落ちる）。

import 'dart:convert';

/// 検索語の履歴。イミュータブル。
class SearchHistory {
  /// 保持する最大件数。
  static const int maxEntries = 8;

  /// 保存形式のキー。
  static const String entriesKey = 'entries';

  /// 新しい順の検索語。
  final List<String> entries;

  const SearchHistory(this.entries);

  /// 空の履歴。
  const SearchHistory.empty() : entries = const <String>[];

  bool get isEmpty => entries.isEmpty;

  bool get isNotEmpty => entries.isNotEmpty;

  /// 語を先頭へ積んだ新しい履歴を返す。
  ///
  /// - 前後の空白を落とし、全角空白は半角へ、連続空白は 1 つに畳む。
  /// - 正規化後に空なら、自分自身をそのまま返す（積まない）。
  /// - 大文字小文字を無視して一致する既存語は取り除き、先頭へ移す。
  ///   表記は今回の入力で置き換える。
  /// - [maxEntries] を超えた分は古いものから落とす。
  SearchHistory add(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) return this;

    final lower = normalized.toLowerCase();
    final next = <String>[
      normalized,
      for (final entry in entries)
        if (entry.toLowerCase() != lower) entry,
    ];
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    return SearchHistory(List<String>.unmodifiable(next));
  }

  /// 検索語の空白を正規化する。
  ///
  /// trim → 全角空白 (U+3000) を半角へ → 連続空白を 1 つに畳む。
  static String normalize(String raw) {
    return raw.replaceAll('\u3000', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// JSON 文字列へ符号化する。
  String encode() {
    return jsonEncode(<String, Object?>{
      entriesKey: <String>[...entries],
    });
  }

  /// JSON 文字列を復号する。**決して例外を投げない。**
  ///
  /// null・空文字・壊れた JSON・型不一致・非文字列要素は捨て、
  /// 既定（空の履歴）へ落ちる。
  static SearchHistory decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SearchHistory.empty();
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const SearchHistory.empty();
    }
    if (decoded is! Map) {
      return const SearchHistory.empty();
    }

    final value = decoded[entriesKey];
    if (value is! List) {
      return const SearchHistory.empty();
    }

    final result = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final normalized = normalize(item);
      if (normalized.isEmpty) continue;
      result.add(normalized);
      if (result.length >= maxEntries) break;
    }
    return SearchHistory(List<String>.unmodifiable(result));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchHistory) return false;
    if (other.entries.length != entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (other.entries[i] != entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);

  @override
  String toString() => 'SearchHistory($entries)';
}
