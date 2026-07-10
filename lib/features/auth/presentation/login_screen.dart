import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/core/infrastructure/auth_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// Googleログイン画面。
///
/// 未ログイン時に表示され、Googleネイティブ認証でSupabaseセッションを確立する。
/// 認証成功後は [AuthService] の onAuthStateChange を監視する AuthGate が
/// 自動的に MainScreen へ遷移させる。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await getIt<AuthService>().signInWithGoogle();
      // 成功時は AuthGate が onAuthStateChange で MainScreen へ遷移。
    } on GoogleSignInException catch (e) {
      // キャンセルは静かに無視。それ以外はメッセージ表示。
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = 'Googleログインに失敗しました: ${e.code.name}');
      }
    } catch (e) {
      setState(() => _error = 'ログインに失敗しました。通信環境をご確認ください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 16),
                  const Text(
                    '冒険者ギルドへようこそ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'クエストの記録は\nアカウントに安全に保管されます',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'google_sign_in'),
                    label: 'Googleでログイン',
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login, size: 20),
                      label: Text(
                        _loading ? 'ログイン中...' : 'Googleでログイン',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
