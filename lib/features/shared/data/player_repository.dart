import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';

/// Release でも logcat に出力する簡易ロガー
void _log(String msg) {
  // ignore: avoid_print
  print('[PlayerRepo] $msg');
}

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
    _log('Loading player...');
    try {
      final box = await _getBox();
      _log('box.length=${box.length}, box.keys=${box.keys.toList()}');
      if (box.isNotEmpty) {
        final player = box.getAt(0);
        if (player != null) {
          _log('Player found (Lv.${player.level}, coins=${player.coins}, job=${player.currentJob}, jobLevels=${player.jobLevels})');
          return player;
        } else {
          _log('box.getAt(0) returned null!');
        }
      }
    } catch (e, s) {
      _log('Load failed: $e');
      _log('Stack: $s');
      return null;
    }
    _log('No player found, returning null.');
    return null;
  }



  @override
  Future<void> savePlayer(Player player) async {
    _log('Saving player (Lv.${player.level}, coins=${player.coins}, job=${player.currentJob})');
    final box = await _getBox();
    await box.put(0, player);
    await box.flush();
    // 読み戻して確認
    final verify = box.getAt(0);
    _log('Saved & flushed. Verify: Lv.${verify?.level}, coins=${verify?.coins}');
  }

  @override
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
