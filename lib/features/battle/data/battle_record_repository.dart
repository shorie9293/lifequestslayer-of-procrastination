import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';

/// 討伐戦績（改善提案 #56）の永続化リポジトリ抽象。
abstract class BattleRecordRepository {
  /// 全戦績を古い順（occurredAt 昇順・同時刻は id 昇順）で取得する。
  Future<List<BattleRecord>> load();

  /// 戦績を1件追加する（同一 ID は上書き・500件上限で最古を削除）。
  Future<void> add(BattleRecord record);

  /// 全戦績を削除する（試練用）。
  Future<void> clear();
}

/// [BattleRecordRepository] の Hive 実装。
///
/// Hive Box `battle_records` に キー = 記録ID / 値 = JSON文字列 で保存する。
/// Hive の TypeAdapter 登録を要さないため異種端末・移行に強い。
/// 破損レコードは読み飛ばし、健全な履歴を守る（全損させない）。
class HiveBattleRecordRepository implements BattleRecordRepository {
  static const String boxName = 'battle_records';

  /// 保持する戦績の上限件数（超過時は最古を削除）。
  static const int maxRecords = 500;

  final Box<String>? _injectedBox;

  /// 試練用: Box を外から注入する（実 Hive を触らずに検証できる）。
  HiveBattleRecordRepository({Box<String>? box}) : _injectedBox = box;

  Box<String>? _openedBox;

  Future<Box<String>> _getBox() async {
    final injected = _injectedBox;
    if (injected != null) return injected;
    final opened = _openedBox;
    if (opened != null && opened.isOpen) return opened;
    _openedBox = await Hive.openBox<String>(boxName);
    return _openedBox!;
  }

  /// Hive 未初期化（UI試練環境など）では null を返す。
  ///
  /// 戦績はベストエフォート記録であるため、永続層の不在で画面を落としてはならない。
  Future<Box<String>?> _getBoxOrNull() async {
    try {
      return await _getBox();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BattleRecord>> load() async {
    final box = await _getBoxOrNull();
    if (box == null) return const [];
    final records = <BattleRecord>[];
    for (final raw in box.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        records.add(BattleRecord.fromJson(decoded));
      } catch (_) {
        // 破損レコードは無視する（履歴全体を失わないため）
      }
    }
    final list = records.toList()
      ..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  @override
  Future<void> add(BattleRecord record) async {
    final box = await _getBoxOrNull();
    if (box == null) return;
    // 同一 ID は上書き（重複防止）。
    await box.put(record.id, jsonEncode(record.toJson()));
    // 上限超過時は最古（occurredAt 昇順・同時刻は id 昇順の先頭）を削除。
    final excess = box.length - maxRecords;
    if (excess <= 0) return;
    final entries = <_Dated>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! String) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        entries.add(_Dated(key.toString(), BattleRecord.fromJson(decoded)));
      } catch (_) {
        // 破損エントリは削除候補の整列対象外（読み飛ばし対象）。
      }
    }
    entries.sort((a, b) {
      final byTime = a.record.occurredAt.compareTo(b.record.occurredAt);
      if (byTime != 0) return byTime;
      return a.key.compareTo(b.key);
    });
    for (var i = 0; i < min(excess, entries.length); i++) {
      await box.delete(entries[i].key);
    }
  }

  @override
  Future<void> clear() async {
    final box = await _getBoxOrNull();
    if (box == null) return;
    await box.clear();
  }
}

class _Dated {
  final String key;
  final BattleRecord record;
  const _Dated(this.key, this.record);
}

/// 永続層が未配線の環境（UI試練など）で使う無害な実装。
///
/// Hive を一切触らないため、Hive 未初期化でも画面を落とさない。
/// ⚠️ Hive の `openBox` は失敗を **共有 Completer にも流す**ため、
/// 呼出側の try/catch だけでは zone の未処理エラーを抑止できない
/// （flutter_test では必ずテスト失敗になる）→ 未初期化環境では
/// Hive に触れないこの実装を既定にすること。
class NoopBattleRecordRepository implements BattleRecordRepository {
  @override
  Future<List<BattleRecord>> load() async => const [];

  @override
  Future<void> add(BattleRecord record) async {}

  @override
  Future<void> clear() async {}
}

/// [BattleRecordRepository] の試練用インメモリ実装（同じ意味論）。
class InMemoryBattleRecordRepository implements BattleRecordRepository {
  final Map<String, BattleRecord> _store = {};

  @override
  Future<List<BattleRecord>> load() async {
    final list = _store.values.toList()
      ..sort((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  @override
  Future<void> add(BattleRecord record) async {
    _store[record.id] = record;
    while (_store.length > HiveBattleRecordRepository.maxRecords) {
      final oldest = _store.values.reduce((a, b) {
        final byTime = a.occurredAt.compareTo(b.occurredAt);
        if (byTime != 0) return byTime < 0 ? a : b;
        return a.id.compareTo(b.id) < 0 ? a : b;
      });
      _store.remove(oldest.id);
    }
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}
