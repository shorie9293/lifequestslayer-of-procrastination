// 検索語履歴の SharedPreferences 保存先の試練。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/core/search/search_history.dart';
import 'package:rpg_todo/core/search/search_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = SharedPreferencesSearchHistoryStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('未保存なら空の履歴を返す', () async {
    final loaded = await store.load();

    expect(loaded.entries, isEmpty);
  });

  test('保存した履歴をそのまま読み戻せる', () async {
    final history = const SearchHistory.empty().add('討伐').add('採集');

    await store.save(history);
    final loaded = await store.load();

    expect(loaded, history);
    expect(loaded.entries, ['採集', '討伐']);
  });

  test('保存は既存の値を上書きする', () async {
    await store.save(const SearchHistory.empty().add('古い語'));
    await store.save(const SearchHistory.empty().add('新しい語'));

    final loaded = await store.load();

    expect(loaded.entries, ['新しい語']);
  });

  test('格納キーは guild_search_history_v1 である', () async {
    await store.save(const SearchHistory.empty().add('討伐'));

    final prefs = await SharedPreferences.getInstance();

    expect(SharedPreferencesSearchHistoryStore.storageKey,
        'guild_search_history_v1');
    expect(prefs.getString('guild_search_history_v1'), isNotNull);
  });

  test('壊れた保存値でも例外を投げず空へ落ちる', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'guild_search_history_v1': '{壊れた json',
    });

    final loaded = await store.load();

    expect(loaded.entries, isEmpty);
  });
}
