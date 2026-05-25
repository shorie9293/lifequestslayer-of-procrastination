import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';

class PlayerRepository implements IPlayerRepository {
  static const String boxName = 'playerBox';

  // v1.5: Box インスタンスをキャッシュして毎回の openBox を回避
  Box<Player>? _box;

  Future<Box<Player>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Player>(boxName);
    return _box!;
  }

  @override
  Future<Player?> loadPlayer() async {
    debugPrint('PlayerRepository: Loading player...');
    try {
      final box = await _getBox();
      if (box.isNotEmpty) {
        final player = box.getAt(0);
        if (player != null) {
          debugPrint('PlayerRepository: Player found (Lv.${player.level})');
          return player;
        }
      }
    } catch (e) {
      // v1.3-fix: 読み込み失敗時はBoxを削除せずnullを返す。
      // データ破損でも保存データは保持し、次回起動時の修復を期待する。
      debugPrint(
          'PlayerRepository: Load failed (player data may be corrupted): $e');
      return null;
    }
    debugPrint('PlayerRepository: No player found, returning null.');
    return null;
  }



  @override
  Future<void> savePlayer(Player player) async {
    debugPrint('PlayerRepository: Saving player (Lv.${player.level})...');
    final box = await _getBox();
    await box.put(0, player);
    // v1.5: 即座にディスクへ反映（OS kill 耐性の向上）
    await box.flush();
    debugPrint('PlayerRepository: Player saved and flushed.');
  }

  @override
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
