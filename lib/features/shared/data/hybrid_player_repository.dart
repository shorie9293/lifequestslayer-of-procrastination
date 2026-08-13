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

      // ローカルにもクラウドにも無い → 何もしない
      if (localPlayer == null && remotePlayer == null) return;

      // last-write-wins。両方ある場合は updatedAt が新しい方を採用（同時はローカル優先）。
      Player? winner;
      if (localPlayer != null && remotePlayer == null) {
        winner = localPlayer; // ローカルのみ → ローカルをクラウドへ push
      } else if (localPlayer == null) {
        winner = remotePlayer; // クラウドのみ → ローカルへ取得
      } else {
        final localTs = localPlayer.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final remoteTs = remotePlayer!.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        winner = remoteTs.isAfter(localTs) ? remotePlayer : localPlayer;
      }

      if (winner == null) return;

      // 採用した方を Hive と Supabase の両方に書き込む（整合を保つ）
      await _hiveRepo.savePlayer(winner);
      await _supabaseRepo.savePlayer(winner);
      debugPrint(
          '[HybridPlayerRepo] Synced (Lv.${winner.level}, coins=${winner.coins})');
    } catch (e) {
      debugPrint('[HybridPlayerRepo] Sync failed (offline): $e');
    }
  }

  @override
  Future<void> savePlayer(Player player) async {
    // ローカル保存のタイムスタンプを付与（last-write-wins 判定用）
    player.updatedAt = DateTime.now();

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
