/// 削除操作のUndo（元に戻す）用の単一スロットバッファ。
///
/// 純粋・依存なし・ジェネリック。`take()` は値を一度だけ返し、以降は null を
/// 返すため、二重復元（同じ削除を2回取り消すこと）を構造的に防ぐ。
class UndoBuffer<T> {
  T? _item;

  /// 取り消せる値が保持されているか。
  bool get canUndo => _item != null;

  /// 値を保持する。既に値があれば押し出し、押し出された旧値を返す。
  T? push(T item) {
    final previous = _item;
    _item = item;
    return previous;
  }

  /// 保持値を消費せずに覗く。
  T? peek() => _item;

  /// 保持値を取り出す。一度取り出すと以降は null（二重復元防止）。
  T? take() {
    final item = _item;
    _item = null;
    return item;
  }

  /// 保持値を破棄する。
  void clear() {
    _item = null;
  }
}
