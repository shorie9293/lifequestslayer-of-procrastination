import 'package:flutter/foundation.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';

/// Hive（ローカル）と Supabase（クラウド）の二重書き込みハイブリッドリポジトリ。
/// Hiveをプライマリ、Supabaseをセカンダリとする。
class HybridPlayerRepository implements IPlayerRepository {
  final IPlayerRepository _hiveRepo;
  final IPlayerRepository _supabaseRepo;

  HybridPlayerRepository({
    required IPlayerRepository hiveRepo,
    required IPlayerRepository supabaseRepo,
  })  : _hiveRepo = hiveRepo,
        _supabaseRepo = supabaseRepo;

  @override
  bool get loadFailedDueToCorruption => _hiveRepo.loadFailedDueToCorruption;

  @override
  Future<Player?> loadPlayer() async {
    // プライマリ: Hiveから読み込み
    final player = await _hiveRepo.loadPlayer();

    // セカンダリ: Supabaseと同期（awaitで確実に完了を待つ）
    try {
      await _syncFromSupabase(player).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[HybridPlayerRepo] Sync timeout, using local data: $e');
    }

    // マージ後の最新データをHiveから再読み込み
    return await _hiveRepo.loadPlayer();
  }

  Future<void> _syncFromSupabase(Player? localPlayer) async {
    try {
      final remotePlayer = await _supabaseRepo.loadPlayer();
      if (remotePlayer == null) return;

      // リモートのPlayerでローカルを上書き（クラウド最新を信頼）
      await _hiveRepo.savePlayer(remotePlayer);
      debugPrint('[HybridPlayerRepo] Synced from Supabase (Lv.${remotePlayer.level})');
    } catch (e) {
      debugPrint('[HybridPlayerRepo] Sync failed (offline): $e');
    }
  }

  @override
  Future<void> savePlayer(Player player) async {
    // プライマリ: Hiveに即時保存
    await _hiveRepo.savePlayer(player);

    // セカンダリ: Supabaseに非同期保存（失敗は無視）
    _supabaseRepo.savePlayer(player).catchError((e) {
      debugPrint('[HybridPlayerRepo] Supabase save failed (offline): $e');
    });
  }

  @override
  Future<void> close() async {
    await _hiveRepo.close();
    await _supabaseRepo.close();
  }
}
