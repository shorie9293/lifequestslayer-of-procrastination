/// 入力途中の長文を誤操作で失わないための純粋判定。
///
/// 画面・ダイアログの「閉じてよいか」を、入力の初期値と現在値の比較だけで決める。
/// 時刻・乱数・環境に依存しないため、試練は固定値で撃てる。
class UnsavedChangesGuard {
  const UnsavedChangesGuard._();

  /// 下書きを保持しない画面の確認文言。
  static const String defaultMessage = '入力内容が失われます。破棄しますか？';

  /// 破棄（閉じる）側のボタン文言。
  static const String discardLabel = '破棄する';

  /// 編集を続ける側のボタン文言。
  static const String keepLabel = '編集を続ける';

  /// 前後の空白を除いて比較する。
  ///
  /// 末尾の改行やインデントだけの差、空白のみの入力は「未変更」とみなす
  /// （誤操作で確認ダイアログを出さないため）。
  static bool isDirty(String initial, String current) {
    return initial.trim() != current.trim();
  }

  /// 複数入力のいずれかに変更があるか。
  ///
  /// 片方にしか無いキーは「変更あり」として扱う（項目の増減を取りこぼさない）。
  static bool isAnyDirty(
    Map<String, String> initial,
    Map<String, String> current,
  ) {
    final keys = <String>{...initial.keys, ...current.keys};
    for (final key in keys) {
      if (isDirty(initial[key] ?? '', current[key] ?? '')) return true;
    }
    return false;
  }

  /// 確認ダイアログの本文。
  static String confirmMessage() => defaultMessage;
}
