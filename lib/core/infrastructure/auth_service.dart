import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/core/infrastructure/supabase_config.dart';

/// Google ネイティブ認証 → Supabase セッション確立を担うサービス。
///
/// google_sign_in 7.x の新API（シングルトン + initialize + authenticate）に準拠。
/// - 認証(authenticate)で得た ID トークンを Supabase の signInWithIdToken へ渡す。
/// - RLS は auth.uid()::text = user_id で保護され、user_id は Google アカウント
///   単位で不変（端末変更・再インストールに耐える）。
class AuthService {
  final SupabaseClient _supabase;
  bool _initialized = false;

  AuthService(this._supabase);

  /// google_sign_in の1回限りの初期化。authenticate 前に必ず呼ぶ。
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: SupabaseConfig.googleServerClientId,
    );
    _initialized = true;
  }

  /// Google ネイティブ認証を実行し、Supabase セッションを確立する。
  ///
  /// キャンセル時は [GoogleSignInException]（code=canceled）が投げられる。
  Future<AuthResponse> signInWithGoogle() async {
    await ensureInitialized();

    final GoogleSignInAccount account =
        await GoogleSignIn.instance.authenticate(
      scopeHint: const <String>['email', 'profile'],
    );

    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google IDトークンの取得に失敗しました');
    }

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// サインアウト（Google + Supabase 両方）。
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[AuthService] GoogleSignIn signOut failed: $e');
    }
    await _supabase.auth.signOut();
  }

  /// 現在のログインユーザー（未ログインなら null）。
  User? get currentUser => _supabase.auth.currentUser;

  /// ログイン済みか。
  bool get isSignedIn => currentUser != null;
}
