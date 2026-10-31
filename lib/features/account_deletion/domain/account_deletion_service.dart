/// アカウント削除（退会）の実行を司るサービス。
///
/// 破壊的操作ゆえ、副作用（端末データ消去・サインアウト）は注入で受け取り、
/// 例外は握り潰さず [AccountDeletionResult] として返す。
library;

/// 削除結果。成功しても失敗しても画面が扱えるよう message と retryable を持つ。
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.success,
    this.message = '',
    this.retryable = false,
  });

  /// 成功。
  const AccountDeletionResult.success()
      : success = true,
        message = '',
        retryable = false;

  /// 失敗（retryable が true なら再試行導線を出してよい）。
  const AccountDeletionResult.failure({
    required String message,
    bool retryable = true,
  })  : success = false,
        message = message,
        retryable = retryable;

  final bool success;
  final String message;
  final bool retryable;
}

/// 削除の実行役。[confirmed] が true のときだけ副作用を起こす。
class AccountDeletionService {
  const AccountDeletionService({
    required this.signOut,
    required this.clearLocalData,
  });

  /// 認証セッションの破棄（Google + Supabase）。
  final Future<void> Function() signOut;

  /// 端末内データの消去。
  final Future<void> Function() clearLocalData;

  /// 削除を実行する。
  ///
  /// 順序は「端末データ消去 → サインアウト」。端末データの消去に失敗したら
  /// セッションは維持したまま failure を返す（success は絶対に返さない）。
  Future<AccountDeletionResult> execute({required bool confirmed}) async {
    if (!confirmed) {
      return const AccountDeletionResult.failure(
        message: '確認が得られていないため削除を中止しました。',
        retryable: false,
      );
    }

    try {
      await clearLocalData();
    } catch (_) {
      return const AccountDeletionResult.failure(
        message: '端末のデータ削除に失敗しました。通信環境を確認して再試行してください。',
      );
    }

    try {
      await signOut();
    } catch (_) {
      return const AccountDeletionResult.failure(
        message: '端末のデータは削除しましたが、サインアウトに失敗しました。再試行してください。',
      );
    }

    return const AccountDeletionResult.success();
  }
}
