// 寄合所クエスト検索の検索条件（検索語・絞り込み・並び順）の永続化。
//
// - GuildQuestQueryPreferences: JSON 文字列との純粋な相互変換（副作用なし）
// - GuildQuestQueryPreferencesStore: 保存先の抽象（試練で差し替え可能）
// - SharedPreferencesGuildQuestQueryPreferencesStore: 本番の保存先
//
// decode は絶対に例外を投げない。起動時に読むため、壊れた値でも
// 既定クエリへ静かに落ちることが最優先である。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';

/// 検索条件と JSON 文字列の相互変換。
class GuildQuestQueryPreferences {
  GuildQuestQueryPreferences._();

  /// 保存形式のキー
  static const String textKey = 'text';
  static const String statusesKey = 'statuses';
  static const String ranksKey = 'ranks';
  static const String tagsKey = 'tags';
  static const String sortOrderKey = 'sortOrder';

  /// クエリを JSON 文字列へ符号化する。
  static String encode(GuildQuestQuery query) {
    return jsonEncode(<String, Object?>{
      textKey: query.text,
      statusesKey: <String>[for (final s in query.statuses) s.name],
      ranksKey: <String>[for (final r in query.ranks) r.name],
      tagsKey: <String>[for (final t in query.tags) t],
      sortOrderKey: query.sortOrder.name,
    });
  }

  /// JSON 文字列を復号する。**決して例外を投げない。**
  ///
  /// null・空文字・壊れた JSON・型不一致は、そのフィールドだけ既定値へ落とす。
  /// 未知の enum 名・未知のキーは無視する。
  static GuildQuestQuery decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const GuildQuestQuery();
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const GuildQuestQuery();
    }
    if (decoded is! Map) {
      return const GuildQuestQuery();
    }

    return GuildQuestQuery(
      text: _readText(decoded[textKey]),
      statuses:
          _readEnumSet(decoded[statusesKey], GuildQuestStatusFilter.values),
      ranks: _readEnumSet(decoded[ranksKey], QuestRank.values),
      tags: _readTags(decoded[tagsKey]),
      sortOrder: _readEnum(decoded[sortOrderKey], GuildQuestSortOrder.values) ??
          GuildQuestSortOrder.deadlineAsc,
    );
  }

  static String _readText(Object? value) {
    if (value is String) return value;
    return '';
  }

  static T? _readEnum<T extends Enum>(Object? value, List<T> values) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }

  /// 未知の enum 名と重複は落とし、型不一致は空集合にする。
  static Set<T> _readEnumSet<T extends Enum>(Object? value, List<T> values) {
    if (value is! List) return <T>{};
    final result = <T>{};
    for (final item in value) {
      final parsed = _readEnum(item, values);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  /// tags は trim し、空文字を捨てる。
  static Set<String> _readTags(Object? value) {
    if (value is! List) return <String>{};
    final result = <String>{};
    for (final item in value) {
      if (item is! String) continue;
      final tag = item.trim();
      if (tag.isEmpty) continue;
      result.add(tag);
    }
    return result;
  }
}

/// 検索条件の保存先（試練で差し替えるための抽象）。
abstract class GuildQuestQueryPreferencesStore {
  /// 保存済みの条件。未保存なら null。
  Future<GuildQuestQuery?> load();

  /// 条件を保存する。
  Future<void> save(GuildQuestQuery query);
}

/// SharedPreferences による保存先。
///
/// 端末側の失敗（プラグイン未登録・容量不足など）で画面を落とさないよう、
/// load は null、save は無音成功として扱う。
class SharedPreferencesGuildQuestQueryPreferencesStore
    implements GuildQuestQueryPreferencesStore {
  const SharedPreferencesGuildQuestQueryPreferencesStore();

  static const String storageKey = 'guild_quest_search_query_v1';

  @override
  Future<GuildQuestQuery?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      return GuildQuestQueryPreferences.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(GuildQuestQuery query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        GuildQuestQueryPreferences.encode(query),
      );
    } catch (_) {
      // 保存できなくても検索は続けられる。ここで例外を投げない。
    }
  }
}
