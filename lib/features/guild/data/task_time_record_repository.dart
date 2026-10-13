import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import 'package:rpg_todo/features/guild/domain/task_time_record.dart';

/// 見積もり時間記録（改善提案 #131）の永続化リポジトリ抽象。
abstract class TaskTimeRecordRepository {
  /// 全記録を新しい順（recordedAt 降順・同時刻は taskId 昇順）で取得する。
  Future<List<TaskTimeRecord>> loadAll();

  /// 記録を1件保存する（同一 id は上書き・500件上限で最古を削除）。
  Future<void> save(TaskTimeRecord record);

  /// 指定 id の記録を1件削除する。
  Future<void> delete(String id);

  /// 全記録を削除する（試練用）。
  Future<void> clear();
}

/// [TaskTimeRecordRepository] の Hive 実装。
///
/// Hive Box `task_time_records` に キー = 記録ID / 値 = JSON文字列 で保存する。
/// Hive の TypeAdapter 登録を要さないため異種端末・移行に強い。
/// 破損レコードは読み飛ばし、健全な履歴を守る（全損させない）。
class HiveTaskTimeRecordRepository implements TaskTimeRecordRepository {
  static const String boxName = 'task_time_records';

  /// 保持する記録の上限件数（超過時は最古を削除）。
  static const int maxRecords = 500;

  final Box<String>? _injectedBox;

  /// 試練用: Box を外から注入する（実 Hive を触らずに検証できる）。
  HiveTaskTimeRecordRepository({Box<String>? box}) : _injectedBox = box;

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
  /// 記録はベストエフォートであるため、永続層の不在で画面を落としてはならない。
  Future<Box<String>?> _getBoxOrNull() async {
    try {
      return await _getBox();
    } catch (_) {
      return null;
    }
  }

  List<TaskTimeRecord> _decodeAll(Box<String> box) {
    final records = <TaskTimeRecord>[];
    for (final raw in box.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        records.add(TaskTimeRecord.fromJson(decoded));
      } catch (_) {
        // 破損レコードは無視する（履歴全体を失わないため）
      }
    }
    return records;
  }

  @override
  Future<List<TaskTimeRecord>> loadAll() async {
    final box = await _getBoxOrNull();
    if (box == null) return const [];
    final records = _decodeAll(box)
      ..sort((a, b) {
        final byTime = b.recordedAt.compareTo(a.recordedAt);
        if (byTime != 0) return byTime;
        return a.taskId.compareTo(b.taskId);
      });
    return records;
  }

  @override
  Future<void> save(TaskTimeRecord record) async {
    final box = await _getBoxOrNull();
    if (box == null) return;
    // 同一 id は上書き（重複防止）。
    await box.put(record.id, jsonEncode(record.toJson()));
    // 上限超過時は最古（recordedAt 昇順・同時刻は taskId 昇順の先頭）を削除。
    final excess = box.length - maxRecords;
    if (excess <= 0) return;
    final entries = <_Dated>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! String) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        entries.add(_Dated(key.toString(), TaskTimeRecord.fromJson(decoded)));
      } catch (_) {
        // 破損エントリは削除候補の整列対象外（読み飛ばし対象）。
      }
    }
    entries.sort((a, b) {
      final byTime = a.record.recordedAt.compareTo(b.record.recordedAt);
      if (byTime != 0) return byTime;
      return a.record.taskId.compareTo(b.record.taskId);
    });
    for (var i = 0; i < min(excess, entries.length); i++) {
      await box.delete(entries[i].key);
    }
  }

  @override
  Future<void> delete(String id) async {
    final box = await _getBoxOrNull();
    if (box == null) return;
    await box.delete(id);
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
  final TaskTimeRecord record;
  const _Dated(this.key, this.record);
}

/// [TaskTimeRecordRepository] の試練用インメモリ実装（同じ意味論）。
class InMemoryTaskTimeRecordRepository implements TaskTimeRecordRepository {
  final Map<String, TaskTimeRecord> _store = {};

  @override
  Future<List<TaskTimeRecord>> loadAll() async {
    final list = _store.values.toList()
      ..sort((a, b) {
        final byTime = b.recordedAt.compareTo(a.recordedAt);
        if (byTime != 0) return byTime;
        return a.taskId.compareTo(b.taskId);
      });
    return list;
  }

  @override
  Future<void> save(TaskTimeRecord record) async {
    _store[record.id] = record;
    while (_store.length > HiveTaskTimeRecordRepository.maxRecords) {
      final oldest = _store.values.reduce((a, b) {
        final byTime = a.recordedAt.compareTo(b.recordedAt);
        if (byTime != 0) return byTime < 0 ? a : b;
        return a.taskId.compareTo(b.taskId) < 0 ? a : b;
      });
      _store.remove(oldest.id);
    }
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}
