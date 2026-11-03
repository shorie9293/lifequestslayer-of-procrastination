import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';

/// Supabase上のプレイヤーデータを管理するリポジトリ。
/// [IPlayerRepository] インターフェースを実装し、JSONBカラムにPlayerを格納する。
class SupabasePlayerRepository implements IPlayerRepository {
  final SupabaseClient _client;

  SupabasePlayerRepository(this._client);

  /// 未ログイン時は null。null 安全化により currentUser! の NPE を排除。
  String? get _userId => _client.auth.currentUser?.id;

  @override
  bool loadFailedDueToCorruption = false;

  @override
  Future<Player?> loadPlayer() async {
    final userId = _userId;
    if (userId == null) {
      appLog.debug('[SupabasePlayerRepo] loadPlayer skipped: not signed in');
      return null;
    }
    try {
      final response = await _client
          .from('rpg_players')
          .select('data')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return Player.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      appLog.warn('[SupabasePlayerRepo] loadPlayer failed: $e');
      return null;
    }
  }

  @override
  Future<void> savePlayer(Player player) async {
    final userId = _userId;
    if (userId == null) {
      appLog.debug('[SupabasePlayerRepo] savePlayer skipped: not signed in');
      return;
    }
    try {
      await _client.from('rpg_players').upsert({
        'user_id': userId,
        'data': player.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      appLog.warn('[SupabasePlayerRepo] savePlayer failed: $e');
    }
  }

  @override
  Future<void> close() async {
    // SupabaseClient は外部管理のため何もしない
  }
}
