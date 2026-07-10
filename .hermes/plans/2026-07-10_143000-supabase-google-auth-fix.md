# rpg-task Supabase連携 修復 実装計画（改訂版: マルチユーザー / Googleログイン）

> **For Hermes:** subagent-driven-development で task-by-task 実装。各タスクで TDD (RED→GREEN→REFACTOR) と二段階レビューを厳守。設定作業（GCP/Supabaseダッシュボード）は創造主様と協働。

**Goal:** 匿名認証をやめ、Googleログイン（Sign in with Google ネイティブ）でマルチユーザー対応にする。RLS (`auth.uid()::text = user_id`) を堅牢に維持し、神託連携（Hermes→タスク追加）を安定したGoogleアカウントuser_idで永続化する。

**Architecture:** `google_sign_in` でネイティブGoogle認証 → IDトークンを `supabase.auth.signInWithIdToken(provider: google)` へ渡す。user_id は Google認証済み `auth.currentUser.id`（不変・端末非依存）。既存匿名データはGoogleログイン後に新user_idへ移行。RLSは既存の `auth.uid()` 方式を維持（緩めない）。

**Tech Stack:** Flutter ^3.5.4, supabase_flutter ^2.8.4, google_sign_in, Hive, Provider, get_it/injectable。applicationId=`com.shorie.lifequest`。Supabase=kxklkgxpjwddufjccvoj。

---

## 設計方針の転換（神議で確定 2026-07-10）

創造主様の決定: **「個人アプリではなく複数ユーザー使う前提にする」**。
→ 自己申告user_id（連携コード）方式は他人データが覗ける穴なので**却下**。
→ **Google認証で本物のログイン**を導入し、RLS `auth.uid()::text = user_id` を堅牢に維持する。

### 現状診断（証拠付き — service_role実測）
- `rpg_players` 10ユーザー / `rpg_tasks` は2ユーザー分のみ（`27cb...673d`=76件, `test-user-001`=1件）
- 匿名UUIDが端末変更で毎回別人化 → playerが10人に増殖した実態
- サインイン失敗をサイレント握り潰し → 同期が黙って死ぬ
- oracle_add_task.py に service_roleキー平文直書き（セキュリティ禍津）

---

## Phase 0: 設定作業（創造主様と協働、コード実装前）

### Task 0-1: SHA-1署名フィンガープリント取得
**Objective:** GCP OAuth Android クライアントID作成に必要なSHA-1を取得。
```bash
cd /home/horie/Takamagahara/utsushiyo/rpg-task
# デバッグ用
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
# 本番用（Play署名鍵 / upload鍵）: android/ の keystore を確認
```
**成果物:** debug用 + release用（upload鍵）のSHA-1（両方GCPに登録）。Play App Signing使用時はPlay Console→アプリの整合性→App signing のSHA-1も登録。

### Task 0-2: Google Cloud Console で OAuth クライアントID作成
**手順（創造主様のGCPアカウント Horie.shunta@gmail.com で）:**
1. https://console.cloud.google.com/auth/clients
2. OAuth同意画面のスコープ設定: `openid`, `userinfo.email`, `userinfo.profile`
3. **Android用クライアントID**作成: パッケージ名 `com.shorie.lifequest` + 上記SHA-1（debug/release両方）
4. **Web用クライアントID**作成: これが `serverClientId` として Flutter/Supabase 両方で使う本体
**成果物:** Web Client ID, Web Client Secret, Android Client ID。

### Task 0-3: Supabase ダッシュボードで Google Provider 有効化
1. Supabase → Authentication → Providers → Google → Enable
2. **Authorized Client IDs** に Web Client ID を先頭に、続けて Android Client ID をカンマ連結で全登録
3. Client Secret に Web の secret を設定
**成果物:** Google provider 有効化完了。

---

## Phase 1: コード実装（TDD）

## Task 1: google_sign_in パッケージ追加 + serverClientId設定
**Files:** Modify `pubspec.yaml`, Create `lib/core/infrastructure/supabase_config.dart`（googleServerClientId追加）
```bash
flutter pub add google_sign_in
```
`supabase_config.dart` に追加:
```dart
static const String googleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'); // = Web Client ID
```
**commit** `git commit -m "chore: google_sign_in導入 + serverClientId設定"`

---

## Task 2: AuthService の test を書く（RED）
**Objective:** GoogleサインインしてSupabaseセッションを確立するサービス。
**Files:** Create `lib/core/infrastructure/auth_service.dart`, Test `test/core/infrastructure/auth_service_test.dart`

**Step 1: 失敗するテスト**（GoogleSignIn/SupabaseClientをモック、signInWithIdTokenが呼ばれることを検証）
```dart
// google_sign_in と supabase を抽象化した AuthService.signInWithGoogle() が
// idToken を取得し supabase.auth.signInWithIdToken(provider: google) を呼ぶことをverify
```
**Step 2:** FAIL
**Step 3: 実装**
```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/core/infrastructure/supabase_config.dart';

class AuthService {
  final SupabaseClient _supabase;
  AuthService(this._supabase);

  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: SupabaseConfig.googleServerClientId,
      scopes: ['openid', 'email', 'profile'],
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('ログインがキャンセルされました');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) throw Exception('IDトークン取得失敗');
    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
  bool get isSignedIn => currentUser != null;
}
```
**Step 4:** PASS
**commit** `git commit -m "feat: GoogleログインAuthService（signInWithIdToken）"`

> **注意:** google_sign_in 7.x はAPIが変更（`signIn()`廃止→`authenticate()`）。導入版に合わせ実装調整。6.x系を明示導入するか、7.x新APIに合わせること。Task 1で `flutter pub add google_sign_in` 後に実際のAPIをverifyしてから実装。

---

## Task 3: SupabaseTask/PlayerRepository を null安全化（RED→GREEN）
**Objective:** `_userId = currentUser!.id` の `!` を除去し、未ログイン時は例外でなく空動作＋ログ。
**Files:** Modify `lib/features/guild/data/supabase_task_repository.dart`, `lib/features/shared/data/supabase_player_repository.dart` + それぞれのtest（MockClient, supabase-testing skill参照）
```dart
String? get _userId => _client.auth.currentUser?.id;
// loadTasks/saveTasks 冒頭で if (_userId == null) return [] / return;
```
**commit** `git commit -m "refactor: SupabaseRepo を未ログイン時null安全化"`

---

## Task 4: ログイン画面 + 認証ゲートUI
**Objective:** 未ログイン時はログイン画面、ログイン後にMainScreen。
**Files:** Create `lib/features/auth/presentation/login_screen.dart`, Modify `lib/main.dart`（home を認証状態で分岐）+ widget test
- 「Googleでログイン」ボタン → `AuthService.signInWithGoogle()`
- `supabase.auth.onAuthStateChange` を監視して画面遷移
**commit** `git commit -m "feat: Googleログイン画面 + 認証ゲート"`

---

## Task 5: main.dart の匿名サインイン削除 + DI調整
**Objective:** `signInAnonymously()`（main.dart:41）を削除。DIはログイン後にrepoを再解決 or セッション確立後にVMロード。
**Files:** Modify `lib/main.dart`, `lib/core/di/injection.dart`
- Supabase初期化後、匿名サインインを削除
- `AuthService` を getIt に登録
- ログイン成功後に `initializeViewModels()` 相当を呼びクラウドデータをロード
**検証:** `flutter analyze --no-fatal-infos` → 0 warning
**commit** `git commit -m "refactor: 匿名認証を廃止しGoogle認証ゲートに統合"`

---

## Task 6: 連携ダイアログを Googleアカウント user_id 表示に
**Objective:** `guild_screen.dart:47-49` の連携コードを `currentUser.id`（Google認証後の安定UUID）表示＋ログインメールも表示。
**Files:** Modify `lib/features/guild/presentation/guild_screen.dart`
**commit** `git commit -m "feat: 連携ダイアログをGoogleアカウントID表示に"`

---

## Task 7: 既存匿名データの移行（Googleログイン後）
**Objective:** 匿名user_id（`27cb...673d`=76件）を、創造主様のGoogleログイン後の新user_idへ移行。
**方式:** Supabaseは匿名→OAuthのlinkIdentityに制約があるため、**service_roleでデータのuser_idをUPDATE**する移行スクリプトを使う。
**Files:** Create `scripts/migrate_anon_to_google.py`
```python
# migrate_anon_to_google.py --from <匿名UUID> --to <GoogleログインUUID>
# rpg_tasks / rpg_players の user_id を service_role で UPDATE
```
**手順:** 創造主様が更新版アプリでGoogleログイン → 連携ダイアログで新user_id確認 → スクリプト実行。
**検証:** `rpg_tasks?user_id=eq.<新>` が76件返る。
**commit** `git commit -m "chore: 匿名→Googleアカウント データ移行スクリプト"`

---

## Task 8: oracle_add_task.py のキー秘匿 + user_id更新
**Objective:** service_roleキーを環境変数化。連携先は創造主様のGoogle user_id。
**Files:** Modify `scripts/oracle_add_task.py`
```python
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if not SUPABASE_KEY:
    sys.exit("ERROR: SUPABASE_SERVICE_ROLE_KEY 未設定。BWSから取得せよ。")
```
BWS hermes-production に `RPG_SUPABASE_SERVICE_ROLE_KEY` 登録。
**commit** `git commit -m "security: oracle_add_task キー環境変数化"`

---

## Task 9: RLS 確認（緩めない — migration不要の想定）
**Objective:** 既存 `auth.uid()::text = user_id` RLSがGoogle認証で正しく機能することを確認。
Google認証後の `auth.uid()` は本物のアカウントUUID。既存RLS（migration 001）が**そのまま有効**。migration追加は不要。
**検証:** 別アカウントでログイン→他人のタスクが見えないことをRESTで確認。
**（コミット不要 / 確認のみ）**

---

## Task 10: 統合検証・デプロイ・神書更新
1. `bash scripts/pre-deploy-check.sh` 全PASS
2. deploy.yml に `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` 追加（GitHub secret登録）
3. AppBarバージョン標識更新 `Text("v1.5.0+XX")` + pubspec version同期（メジャー変更なので1.5.0）
4. Tailscale直APKで実機検証: Googleログイン→再インストール後も同一user_id→oracle_add_taskで追加が即反映
5. 神書更新（`03_現世カタログ/📁_rpg-task/`）+ memory更新

---

## Files likely to change
- `lib/core/infrastructure/auth_service.dart`（新規）, `supabase_config.dart`
- `lib/features/auth/presentation/login_screen.dart`（新規）
- `lib/features/guild/data/supabase_task_repository.dart`, `lib/features/shared/data/supabase_player_repository.dart`
- `lib/core/di/injection.dart`, `lib/main.dart`, `lib/features/guild/presentation/guild_screen.dart`
- `scripts/oracle_add_task.py`, `scripts/migrate_anon_to_google.py`（新規）
- `pubspec.yaml`, `.github/workflows/deploy.yml`

## Risks / Open Questions
- **google_sign_in バージョン差異**: 6.x（`signIn()`）と7.x（`authenticate()`）でAPI大幅変更。導入版を確認して実装（Task 1-2）。
- **iOS対応**: 今回Androidのみ。iOS配布時はiOS Client ID + Info.plist追加が別途必要。
- **匿名データ移行**: 移行対象は創造主様の76件のみ想定。他9人の匿名playerは移行不可（本人のGoogleログイン後に空から開始）。→ 許容か要確認。
- **SHA-1**: Play App Signing使用時はPlay Console側のSHA-1も登録必須。
- **設定作業（Phase 0）は創造主様との協働必須**（GCP/Supabaseダッシュボード操作）。
