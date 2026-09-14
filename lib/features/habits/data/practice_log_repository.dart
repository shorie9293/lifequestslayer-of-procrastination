import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/services/practice_log_service.dart';

/// 勤行の日別履歴ログ（道標§五 #50）の永続化リポジトリ。
///
/// Hive Box `practice_logs` に キー = `yyyy-MM-dd` / 値 = JSON文字列 で保存する。
/// Hive の TypeAdapter 登録を要さないため異種端末・移行に強い。
/// 破損レコードは読み飛ばし、健全な履歴を守る（全損させない）。
class PracticeLogRepository {
  static const String boxName = 'practice_logs';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  /// 全ログを日付昇順で取得する（同日重複は統合）。
  Future<List<PracticeLog>> getAll() async {
    final box = await _getBox();
    final logs = <PracticeLog>[];
    for (final raw in box.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        logs.add(PracticeLog.fromJson(decoded));
      } catch (_) {
        // 破損レコードは無視する（履歴全体を失わないため）
      }
    }
    return PracticeLogService.normalize(logs);
  }

  /// [at]（既定は現在時刻）の勤行完遂を [amount] 件記録し、その日のログを返す。
  Future<PracticeLog> record({DateTime? at, int amount = 1}) async {
    final when = at ?? DateTime.now();
    final logs = await getAll();
    final next = PracticeLogService.record(logs, at: when, amount: amount);
    final key = PracticeLog.keyOf(when);
    final entry = next.firstWhere((l) => l.id == key);
    final box = await _getBox();
    await box.put(entry.id, jsonEncode(entry.toJson()));
    return entry;
  }

  /// 件数を取得する。
  Future<int> getCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// 全ログを削除する（試練用）。
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Box を閉じる。
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
