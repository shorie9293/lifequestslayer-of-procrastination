/// パスコード忘却時の回復導線の純粋ロジック。
///
/// 破壊的操作（端末内データ初期化）の手前に置く二段確認の規則を集約する。
/// 状態は一切持たない（試練容易性）。
class LockRecoveryPolicy {
  /// 確認語。ユーザーに手入力させる語。
  static const String confirmationPhrase = '初期化';

  /// ダイアログの警告見出し。
  static const String warningTitle = 'パスコードをお忘れですか？';

  /// ダイアログの警告本文（何が起きるかを正直に書く）。
  static const String warningBody =
      'ロックを解除するには、この端末のデータを初期化する必要があります。\n\n'
      '・回復の前に、できる範囲で自動バックアップを書き出します\n'
      '・初期化に失敗しても、ロックは必ず解除します\n'
      '・初期化後はクエスト・プレイヤー等のデータは失われます';

  /// 確認語の入力欄ラベル。
  static const String confirmationLabel = '確認のため「初期化」と入力';

  /// 回復を実行してよい状態か。ロックが有効な時だけ回復できる。
  static bool canRecover({required bool enabled}) => enabled;

  /// 確認語が一致するか（前後の空白は無視する）。
  static bool isConfirmationValid(String input) =>
      input.trim() == confirmationPhrase;
}
