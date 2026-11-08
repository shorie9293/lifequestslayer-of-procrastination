// 検索語履歴の保存先。
//
// - SearchHistoryStore: 保存先の抽象（試練で差し替え可能）
// - SharedPreferencesSearchHistoryStore: 本番の保存先
//
// 端末側の失敗で画面を落とさないよう、load は空の履歴、
// save は無音成功として扱う。

import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/core/search/search_history.dart';

/// 検索語履歴の保存先。
abstract class SearchHistoryStore {
  /// 保存済みの履歴。未保存・読込失敗なら空の履歴。
  Future<SearchHistory> load();

  /// 履歴を保存する。
  Future<void> save(SearchHistory history);
}

/// SharedPreferences による保存先。
class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  const SharedPreferencesSearchHistoryStore();

  static const String storageKey = 'guild_search_history_v1';

  @override
  Future<SearchHistory> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SearchHistory.decode(prefs.getString(storageKey));
    } catch (_) {
      return const SearchHistory.empty();
    }
  }

  @override
  Future<void> save(SearchHistory history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, history.encode());
    } catch (_) {
      // 保存できなくても検索は続けられる。ここで例外を投げない。
    }
  }
}
