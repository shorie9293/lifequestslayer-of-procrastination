import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/gryphon_report.dart';

/// 週次グリフォン報告の永続化を管理するリポジトリ。
///
/// Hive Box "gryphon_reports" をキー=レポートID で使用する。
/// GryphonReport は toJson/fromJson を持つため Map 形式で格納する。
class GryphonReportRepository {
  static const String boxName = 'gryphon_reports';

  Box<Map>? _box;

  Future<Box<Map>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Map>(boxName);
    return _box!;
  }

  /// グリフォン報告を保存する
  Future<void> save(GryphonReport report) async {
    final box = await _getBox();
    await box.put(report.id, report.toJson());
  }

  /// 直近に生成された報告を取得する（generatedAt 降順の先頭）
  Future<GryphonReport?> getLatest() async {
    final all = await getAll();
    if (all.isEmpty) return null;
    return all.first;
  }

  /// 全報告を取得する（generatedAt 降順）。
  ///
  /// Hive 未初期化（UI試練環境など）では空リストを即返す。
  /// （未開口の箱に対する openBox は flutter_test の FakeAsync で完了しないため、
  /// 読み取り経路で zone汚染を起こさないよう isBoxOpen ガードを設ける）
  Future<List<GryphonReport>> getAll() async {
    if (!Hive.isBoxOpen(boxName)) return const [];
    final box = await _getBox();
    final reports = box.values
        .map((raw) => GryphonReport.fromJson(Map<String, dynamic>.from(raw)))
        .toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return reports;
  }

  /// 指定週の開始日（日曜日）に対応する報告を取得する
  Future<List<GryphonReport>> getByWeekStart(DateTime weekStart) async {
    final normalized = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final all = await getAll();
    return all
        .where((r) =>
            r.weekStartDate.year == normalized.year &&
            r.weekStartDate.month == normalized.month &&
            r.weekStartDate.day == normalized.day)
        .toList();
  }

  /// 報告を削除する（テスト用）
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// 全報告を削除する（テスト用）
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