import 'package:hive/hive.dart';
import '../../../domain/models/reflection.dart';

/// 振り返りデータの永続化を担当するリポジトリ。
///
/// Hive Box `reflectionsBox` を使用し、
/// key=reflection.id, value=Reflection で保存する。
class ReflectionRepository {
  static const String boxName = 'reflectionsBox';

  Box<Reflection>? _box;

  Future<Box<Reflection>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Reflection>(boxName);
    return _box!;
  }

  /// 振り返りを保存
  Future<void> save(Reflection reflection) async {
    final box = await _getBox();
    await box.put(reflection.id, reflection);
  }

  /// 全振り返りを取得
  Future<List<Reflection>> loadAll() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// 指定週（日曜始まり）の振り返りのみを取得
  Future<List<Reflection>> loadByWeek(DateTime weekStart) async {
    final all = await loadAll();
    final normalizedStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd =
        normalizedStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return all.where((r) {
      return !r.date.isBefore(normalizedStart) &&
          !r.date.isAfter(weekEnd);
    }).toList();
  }

  /// 全振り返りの週サマリー（週開始日→件数）を取得
  Future<Map<DateTime, int>> loadWeeklySummaries() async {
    final all = await loadAll();
    final Map<DateTime, int> summaries = {};

    for (final r in all) {
      // 週の開始日（日曜日）でグループ化
      final daysSinceSunday = r.date.weekday % 7;
      final weekStart = DateTime(
        r.date.year,
        r.date.month,
        r.date.day - daysSinceSunday,
      );
      summaries[weekStart] = (summaries[weekStart] ?? 0) + 1;
    }

    return summaries;
  }

  /// 振り返りを削除
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// 全振り返りを削除（テスト用）
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  /// 振り返りの総数を取得
  Future<int> get count async {
    final box = await _getBox();
    return box.length;
  }

  /// Box を閉じる
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
