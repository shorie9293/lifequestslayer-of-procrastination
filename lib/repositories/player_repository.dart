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
      // v1.6: 破損または旧形式の Box を自動修復（削除して初期化）
      debugPrint('PlayerRepository: Load failed (corrupted/incompatible data), deleting box: $e');
      await _closeAndDeleteBox();
    }
    debugPrint('PlayerRepository: No player found, returning default.');
    return Player();
  }

  /// 破損 Box を削除（次回アクセス時に自動再作成される）
  Future<void> _closeAndDeleteBox() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      _box = null;
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {
      // 削除失敗時も次回起動でリトライされるため無視
    }
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
