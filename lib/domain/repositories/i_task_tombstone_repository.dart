/// クエスト削除の墓標（tombstone）を扱うリポジトリ。
///
/// 削除したクエストが cron・他端末・API によって再登録され、
/// 同期マージで「復活」するのを防ぐための台帳。
abstract class ITaskTombstoneRepository {
  /// 削除済みとして記録する（同じ id の再送は無害＝冪等）。
  Future<void> markDeleted(Iterable<String> taskIds, {String? source});

  /// 削除済み id の集合を返す。
  Future<Set<String>> loadTombstones();

  /// 墓標を解除する（復元・Undo でタスクを戻したとき）。
  Future<void> clear(Iterable<String> taskIds);
}
