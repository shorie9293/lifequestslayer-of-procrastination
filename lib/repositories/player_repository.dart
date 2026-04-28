import 'package:hive/hive.dart';
import '../models/player.dart';

class PlayerRepository {
  static const String boxName = 'playerBox';

  Future<Player> loadPlayer() async {
    print("PlayerRepository: Loading player...");
    final box = await Hive.openBox<Player>(boxName);
    if (box.isNotEmpty) {
      print("PlayerRepository: Player found (Lv.${box.getAt(0)!.level})");
      return box.getAt(0)!;
    }
    print("PlayerRepository: No player found, returning default.");
    return Player(); // Default player
  }

  Future<void> savePlayer(Player player) async {
    print("PlayerRepository: Saving player (Lv.${player.level})...");
    final box = await Hive.openBox<Player>(boxName);
    await box.put(0, player);
    print("PlayerRepository: Player saved.");
  }
}
