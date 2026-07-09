/// rpg-task Supabase設定
/// --dart-define で環境変数から注入
class SupabaseConfig {
  /// SupabaseプロジェクトのURL
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Supabaseの匿名キー
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
