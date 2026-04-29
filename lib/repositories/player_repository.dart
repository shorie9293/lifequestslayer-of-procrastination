import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';

class PlayerRepository {
  static const String boxName = 'playerBox';

  Future<Player> loadPlayer() async {
    debugPrint('PlayerRepository: Loading player...');
    final box = await Hive.openBox<Player>(boxName);
    if (box.isNotEmpty) {
      debugPrint('PlayerRepository: Player found (Lv.${box.getAt(0)!.level})');
      return box.getAt(0)!;
    }
    debugPrint('PlayerRepository: No player found, returning default.');
    return Player();
  }

  Future<void> savePlayer(Player player) async {
    debugPrint('PlayerRepository: Saving player (Lv.${player.level})...');
    final box = await Hive.openBox<Player>(boxName);
    await box.put(0, player);
    debugPrint('PlayerRepository: Player saved.');
  }
}
