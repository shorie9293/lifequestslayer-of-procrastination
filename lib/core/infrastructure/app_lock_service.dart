import 'app_lock_repository.dart';
import 'lock_attempt_policy.dart';

/// アプリロックの状態と検証を担う純粋ロジック。
class AppLockService {
  final AppLockRepository _repository;
  final DateTime Function() _now;

  /// [now] は試練用の時刻注入（既定は `DateTime.now`）。
  AppLockService(this._repository, {DateTime Function() now = DateTime.now})
      : _now = now;

  bool get isLocked => _repository.isEnabled();

  /// 復帰時の再施錠猶予。既定は 0（即時）。
  Duration get relockGrace =>
      Duration(seconds: _repository.getRelockGraceSeconds());

  Future<void> setRelockGrace(Duration grace) {
    if (grace.isNegative) {
      throw ArgumentError.value(grace, 'grace', '負の猶予は指定できない');
    }
    return _repository.setRelockGraceSeconds(grace.inSeconds);
  }

  /// 現在ロックアウト中か。
  bool get isLockedOut =>
      LockAttemptPolicy.isLockedOut(_repository.getLockedUntil(), _now());

  /// ロックアウトの残り秒数（ロックアウトなしは 0）。
  int get lockoutRemainingSeconds {
    final until = _repository.getLockedUntil();
    if (until == null) return 0;
    return LockAttemptPolicy.remainingSeconds(until, _now());
  }

  /// ロックを解除する。パスコード方式なら照合、生体認証方式なら
  /// 委譲結果で判定。ロックアウト中は照合せず false。
  Future<bool> unlock({
    String? passcode,
    bool biometricSucceeded = false,
  }) async {
    if (!_repository.isEnabled()) return true;
    if (LockAttemptPolicy.isLockedOut(_repository.getLockedUntil(), _now())) {
      return false;
    }
    switch (_repository.getMethod()) {
      case AppLockMethod.none:
        return true;
      case AppLockMethod.passcode:
        if (passcode == null) return false;
        if (_repository.verifyPasscode(passcode)) {
          await _repository.resetAttempts();
          return true;
        }
        final attempts = _repository.getFailedAttempts() + 1;
        await _repository.setFailedAttempts(attempts);
        final lockout = LockAttemptPolicy.lockoutFor(attempts);
        if (lockout > Duration.zero) {
          await _repository.setLockedUntil(_now().add(lockout));
        }
        return false;
      case AppLockMethod.biometric:
        if (biometricSucceeded) {
          await _repository.resetAttempts();
        }
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
    await _repository.resetAttempts();
  }

  Future<void> disable() async {
    await _repository.setEnabled(false);
    await _repository.clearPasscode();
    await _repository.setMethod(AppLockMethod.none);
    await _repository.resetAttempts();
  }
}
