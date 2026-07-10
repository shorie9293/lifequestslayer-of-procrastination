import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/features/auth/presentation/login_screen.dart';
import 'package:rpg_todo/screens/main_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 認証ゲート。Supabase の認証状態を監視し、
/// - 未ログイン → [LoginScreen]
/// - ログイン済み → ViewModel をロードしてから [MainScreen]
/// を表示する。
///
/// Google認証後にクラウドデータ（rpg_tasks/rpg_players）をロードする必要があるため、
/// ログイン確立後に [initializeViewModels] を1回だけ実行する。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _vmInitialized = false;
  bool _initializing = false;

  Future<void> _initVMsOnce() async {
    if (_vmInitialized || _initializing) return;
    _initializing = true;
    try {
      await initializeViewModels();
      if (mounted) setState(() => _vmInitialized = true);
    } finally {
      _initializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Supabaseが未設定（オフライン開発）の場合は認証を要求せず即MainScreenへ。
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = client.auth.currentSession;

        if (session == null) {
          // 未ログイン: VM初期化フラグをリセットしてログイン画面へ。
          _vmInitialized = false;
          return const LoginScreen();
        }

        // ログイン済み: 初回のみVMロード。
        if (!_vmInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _initVMsOnce());
          return const Scaffold(
            backgroundColor: Color(0xFF1A1A2E),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const ErrorBoundary(child: MainScreen());
      },
    );
  }
}
