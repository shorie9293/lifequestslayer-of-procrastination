import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/deadline_reminder_settings.dart';

/// 締切リマインド設定の永続化インターフェース。
///
/// 勤行リマインダー（`ReminderRepository`）とは **キーが独立**している
/// （同一 box `reminderBox` 内の別キー）。片方の保存が他方を上書きしない。
abstract class DeadlineReminderRepository {
  Future<DeadlineReminderSettings> load();
  Future<void> save(DeadlineReminderSettings s);
}

/// Hive 実装。box `reminderBox` / key `deadlineReminder` に JSON 文字列で保存。
/// 破損・型不一致レコードは [DeadlineReminderSettings.defaults] へフォールバック。
class HiveDeadlineReminderRepository implements DeadlineReminderRepository {
  static const String boxName = 'reminderBox';
  static const String keyName = 'deadlineReminder';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  @override
  Future<DeadlineReminderSettings> load() async {
    final box = await _getBox();
    final raw = box.get(keyName);
    if (raw is! String) return DeadlineReminderSettings.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return DeadlineReminderSettings.defaults();
      }
      return DeadlineReminderSettings.fromJson(decoded);
    } catch (_) {
      return DeadlineReminderSettings.defaults();
    }
  }

  @override
  Future<void> save(DeadlineReminderSettings s) async {
    final box = await _getBox();
    await box.put(keyName, jsonEncode(s.toJson()));
  }
}

/// 試練用のメモリ内リポジトリ。初期値を注入できる。
class InMemoryDeadlineReminderRepository implements DeadlineReminderRepository {
  InMemoryDeadlineReminderRepository([DeadlineReminderSettings? initial])
      : _settings = initial ?? DeadlineReminderSettings.defaults();

  DeadlineReminderSettings _settings;

  @override
  Future<DeadlineReminderSettings> load() async => _settings;

  @override
  Future<void> save(DeadlineReminderSettings s) async => _settings = s;
}
