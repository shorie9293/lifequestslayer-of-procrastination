import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/reminder_settings.dart';

/// 勤行リマインダー設定の永続化インターフェース。
abstract class ReminderRepository {
  Future<ReminderSettings> load();
  Future<void> save(ReminderSettings s);
}

/// Hive 実装。box `reminderBox` / key `practiceReminder` に JSON 文字列で保存。
/// 破損・型不一致レコードは [ReminderSettings.defaults] へフォールバックする。
class HiveReminderRepository implements ReminderRepository {
  static const String boxName = 'reminderBox';
  static const String keyName = 'practiceReminder';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  @override
  Future<ReminderSettings> load() async {
    final box = await _getBox();
    final raw = box.get(keyName);
    if (raw is! String) return ReminderSettings.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return ReminderSettings.defaults();
      }
      return ReminderSettings.fromJson(decoded);
    } catch (_) {
      return ReminderSettings.defaults();
    }
  }

  @override
  Future<void> save(ReminderSettings s) async {
    final box = await _getBox();
    await box.put(keyName, jsonEncode(s.toJson()));
  }
}

/// 試練用のメモリ内リポジトリ。初期値を注入できる。
class InMemoryReminderRepository implements ReminderRepository {
  InMemoryReminderRepository([ReminderSettings? initial])
      : _settings = initial ?? ReminderSettings.defaults();

  ReminderSettings _settings;

  @override
  Future<ReminderSettings> load() async => _settings;

  @override
  Future<void> save(ReminderSettings s) async => _settings = s;
}
