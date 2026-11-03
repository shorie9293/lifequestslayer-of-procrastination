/// クエストの「明示削除」だけを持つ任意インターフェース。
///
/// [ITaskRepository.saveTasks] に「渡されなかったIDを消す」差分削除を持たせると、
/// 手元が古い一覧のまま保存された瞬間に、他端末や API がクラウドへ入れた行まで
/// 消える（データ喪失）。削除はこの明示APIだけで行う。
///
/// [ITaskRepository] に足さないのは、既存のフェイク実装（29箇所）を
/// 壊さないため。呼び出し側は `repo is ITaskDeletionRepository` で判定する。
abstract class ITaskDeletionRepository {
  /// 指定IDのクエストを削除する。存在しないIDは無視してよい。
  Future<void> deleteTasks(List<String> ids);
}
