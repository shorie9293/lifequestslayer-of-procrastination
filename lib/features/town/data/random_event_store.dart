import 'package:hive/hive.dart';

/// ランダムイベントの「その日に何回出会ったか」を保存する抽象。
///
/// 具象を差し替え可能にすることで、widget 試練が Hive 未初期化のまま
/// サービスを呼んで zone 汚染を起こす事故を構造的に断つ。
abstract class RandomEventStore {
  Future<int> readCount(String dayKey);

  Future<void> writeCount(String dayKey, int count);
}

/// 本番用: Hive `settingsBox` に日付キー付きで保存する。
///
/// アプリ起動時は `Hive.initFlutter()` 済みゆえ `openBox` は安全。
/// 失敗してもイベント機能だけが静かに止まるよう握り潰す（アプリは継続）。
class HiveRandomEventStore implements RandomEventStore {
  static const String boxName = 'settingsBox';
  static const String prefKey = 'town_events_count';

  @override
  Future<int> readCount(String dayKey) async {
    try {
      final box = await Hive.openBox(boxName);
      final stored = box.get('$prefKey.$dayKey') as String?;
      return int.tryParse(stored ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> writeCount(String dayKey, int count) async {
    try {
      final box = await Hive.openBox(boxName);
      await box.put('$prefKey.$dayKey', '$count');
    } catch (_) {}
  }
}

/// 試練・オフライン用のメモリ実装。
class InMemoryRandomEventStore implements RandomEventStore {
  final Map<String, int> _counts;

  InMemoryRandomEventStore([Map<String, int>? initial])
      : _counts = Map<String, int>.from(initial ?? const <String, int>{});

  Map<String, int> get counts => Map<String, int>.unmodifiable(_counts);

  @override
  Future<int> readCount(String dayKey) async => _counts[dayKey] ?? 0;

  @override
  Future<void> writeCount(String dayKey, int count) async {
    _counts[dayKey] = count;
  }
}
