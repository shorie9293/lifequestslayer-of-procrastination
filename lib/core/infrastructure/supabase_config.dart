/// rpg-task Supabase設定
/// --dart-define で環境変数から注入
class SupabaseConfig {
  /// SupabaseプロジェクトのURL
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Supabaseの匿名キー
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Google OAuth の Web クライアントID（serverClientId として使用）。
  /// ネイティブ Google Sign-In で取得した ID トークンを Supabase が検証する際に必要。
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
}
