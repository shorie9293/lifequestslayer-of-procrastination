/// 設定値の保存結果。
///
/// 保存失敗を「呼出元が判定できる値」として返すための純粋な値オブジェクト。
/// Flutter に依存しないため、domain 層・試練の双方から安全に扱える。
///
/// - 成功: [SettingsWriteResult.success] → [ok] が true、[errorMessage] は null
/// - 失敗: [SettingsWriteResult.failure] → [ok] が false、[errorMessage] は非空
class SettingsWriteResult {
  /// 保存成功。
  const SettingsWriteResult.success()
      : ok = true,
        errorMessage = null;

  /// 保存失敗。[message] は創造主様に見せられる日本語の理由。
  const SettingsWriteResult.failure(String message)
      : ok = false,
        errorMessage = message;

  /// 保存が成功したか。
  final bool ok;

  /// 失敗理由（成功時は null）。
  final String? errorMessage;

  @override
  String toString() => ok
      ? 'SettingsWriteResult.ok'
      : 'SettingsWriteResult.failure($errorMessage)';

  @override
  bool operator ==(Object other) =>
      other is SettingsWriteResult &&
      other.ok == ok &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(ok, errorMessage);
}
