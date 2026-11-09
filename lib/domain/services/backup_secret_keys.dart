/// バックアップから除外する「秘密」キーの判定（純粋 Dart・Hive 非依存）。
///
/// 背景: 許可リスト方式の box バックアップは box 単位でしか守れないため、
/// `settingsBox` に同居するアプリロック（パスコードハッシュ等）が
/// 控え JSON（共有・クラウド退避され得る）に載ってしまう。
/// restore 側でも素通しすると他端末へ施錠が移り回復不能になる。
///
/// 実在キー（`lib/core/infrastructure/app_lock_repository.dart` を grep して確認）:
///   appLock.enabled / appLock.method / appLock.passcodeHash /
///   appLock.relockGraceSeconds / appLock.failedAttempts / appLock.lockedUntil
library;

/// 秘密とみなすキー接頭辞（小文字で比較する）。
///
/// 接頭辞一致のみ。通常の設定キー（fontSizeScale 等）に誤爆しないよう
/// 具体的な接頭辞に限定している。
const List<String> kBackupSecretKeyPrefixes = [
  'applock.', // アプリロック実装の全キー（パスコードハッシュ含む）
  'applock_',
  'app_lock.',
  'app_lock_',
  'passcode',
  'password',
  'pin.',
  'pin_',
  'secret',
  'credential',
  'apikey',
  'api_key',
  'token',
];

/// [key] がバックアップに載せてはならない秘密キーか（大文字小文字無視）。
bool isSecretKey(String key) {
  final lower = key.toLowerCase();
  for (final prefix in kBackupSecretKeyPrefixes) {
    if (lower.startsWith(prefix)) return true;
  }
  return false;
}
