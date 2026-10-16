import 'app_lock_repository.dart';

/// アプリロックの状態と検証を担う純粋ロジック。
class AppLockService {
  final AppLockRepository _repository;
  AppLockService(this._repository);

  bool get isLocked => _repository.isEnabled();

  /// ロックを解除する。パスコード方式なら照合、生体認証方式なら
  /// 委譲結果で判定。
  Future<bool> unlock({
    String? passcode,
    bool biometricSucceeded = false,
  }) async {
    if (!_repository.isEnabled()) return true;
    switch (_repository.getMethod()) {
      case AppLockMethod.none:
        return true;
      case AppLockMethod.passcode:
        if (passcode == null) return false;
        return _repository.verifyPasscode(passcode);
      case AppLockMethod.biometric:
        return biometricSucceeded;
    }
  }

  /// パスコード方式でロックを有効化する。4桁の数字以外は ArgumentError。
  Future<void> enableWithPasscode(String passcode) async {
    if (passcode.length != 4) {
      throw ArgumentError.value(passcode, 'passcode', '4桁の数字を指定せよ');
    }
    if (int.tryParse(passcode) == null) {
      throw ArgumentError.value(passcode, 'passcode', '数字のみ');
    }
    await _repository.setPasscode(passcode);
    await _repository.setMethod(AppLockMethod.passcode);
    await _repository.setEnabled(true);
  }

  Future<void> disable() async {
    await _repository.setEnabled(false);
    await _repository.clearPasscode();
    await _repository.setMethod(AppLockMethod.none);
  }
}
