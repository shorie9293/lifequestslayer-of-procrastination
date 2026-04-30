import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';

class PlayerRepository {
  static const String boxName = 'playerBox';

  // v1.5: Box インスタンスをキャッシュして毎回の openBox を回避
  Box<Player>? _box;

  Future<Box<Player>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Player>(boxName);
    return _box!;
  }

  Future<Player> loadPlayer() async {
    debugPrint('PlayerRepository: Loading player...');
    final box = await _getBox();
    if (box.isNotEmpty) {
      debugPrint('PlayerRepository: Player found (Lv.${box.getAt(0)!.level})');
      return box.getAt(0)!;
    }
    debugPrint('PlayerRepository: No player found, returning default.');
    return Player();
  }

  Future<void> savePlayer(Player player) async {
    debugPrint('PlayerRepository: Saving player (Lv.${player.level})...');
    final box = await _getBox();
    await box.put(0, player);
    // v1.5: 即座にディスクへ反映（OS kill 耐性の向上）
    await box.flush();
    debugPrint('PlayerRepository: Player saved and flushed.');
  }

  // v1.5: リソース解放（dispose 時に呼ぶ）
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
