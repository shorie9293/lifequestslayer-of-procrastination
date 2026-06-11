import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/reflection.dart';

/// 振り返りログの永続化を管理するリポジトリ。
///
/// Hive Box "reflections" をキー=id で使用する。
class ReflectionRepository {
  static const String boxName = 'reflections';

  Box<Reflection>? _box;

  Future<Box<Reflection>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Reflection>(boxName);
    return _box!;
  }

  /// 振り返りを保存する
  Future<void> save(Reflection reflection) async {
    final box = await _getBox();
    await box.put(reflection.id, reflection);
  }

  /// 全振り返りを取得する（日付降順）
  Future<List<Reflection>> getAll() async {
    final box = await _getBox();
    final reflections = box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return reflections;
  }

  /// 指定期間内の振り返りを取得する
  Future<List<Reflection>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final all = await getAll();
    return all
        .where((r) =>
            r.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            r.date.isBefore(end.add(const Duration(seconds: 1))))
        .toList();
  }

  /// 直近N件を取得する
  Future<List<Reflection>> getRecent(int count) async {
    final all = await getAll();
    return all.take(count).toList();
  }

  /// 振り返り総数を取得する
  Future<int> getCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// 振り返りを削除する（テスト用）
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// 全振り返りを削除する（テスト用）
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Boxを閉じる（アプリ終了時など）
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
