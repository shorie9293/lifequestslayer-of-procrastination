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
  static const String _backupBoxName = 'playerBox_backup';

  // v1.5: Box インスタンスをキャッシュして毎回の openBox を回避
  Box<Player>? _box;
  Box? _backupBox;

  /// loadPlayer() がデシリアライズ失敗した場合 true。
  /// ViewModel はこのフラグを見て save() をスキップすべき。
  bool loadFailedDueToCorruption = false;

  Future<Box<Player>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Player>(boxName);
    return _box!;
  }

  Future<Box> _getBackupBox() async {
    if (_backupBox != null && _backupBox!.isOpen) return _backupBox!;
    _backupBox = await Hive.openBox(_backupBoxName);
    return _backupBox!;
  }

  @override
  Future<Player?> loadPlayer() async {
    _log('Loading player...');
    loadFailedDueToCorruption = false;

    try {
      final box = await _getBox();
      _log('box.length=${box.length}, box.keys=${box.keys.toList()}');
      if (box.isNotEmpty) {
        final player = box.getAt(0);
        if (player != null) {
          _log('Player found (Lv.${player.level}, coins=${player.coins}, '
              'job=${player.currentJob}, jobLevels=${player.jobLevels})');
          return player;
        } else {
          _log('box.getAt(0) returned null!');
        }
      }
    } catch (e, s) {
      // ★ デシリアライズ失敗 = バージョンアップ後のデータ不整合
      _log('⚠️ Load FAILED (likely format version mismatch): $e');
      _log('Stack: $s');
      loadFailedDueToCorruption = true;

      // ━━━ Phase 1: 型なしBoxで旧データをバックアップ ━━━
      await _backupRawBoxData();

      // ━━━ Phase 2: 破損Boxを閉じて、クリーンな状態で再開 ━━━
      try {
        if (_box != null && _box!.isOpen) {
          await _box!.close();
          _box = null;
        }
        // 型なしBoxで開き直す（Adapter のデシリアライズをスキップ）
        final rawBox = await Hive.openBox<dynamic>(boxName);
        _log('Raw box reopened: length=${rawBox.length}, keys=${rawBox.keys}');

        // ★ 古いバイナリデータをバックアップBoxに複製
        final backup = await _getBackupBox();
        for (final key in rawBox.keys) {
          try {
            await backup.put('player_$key', rawBox.get(key));
          } catch (_) {}
        }
        await backup.put('recovery_timestamp', DateTime.now().toIso8601String());
        await backup.put('recovery_reason', e.toString());
        await backup.put('recovery_keys', rawBox.keys.toList());
        _log('Raw entries backed up to $_backupBoxName');

        await rawBox.close();
      } catch (backupErr) {
        _log('Raw backup also failed: $backupErr');
      }

      return null;
    }

    _log('No player found, returning null.');
    return null;
  }

  /// Box を型なしで開き、すべてのキーとrawバイト列をバックアップBoxに退避
  Future<void> _backupRawBoxData() async {
    try {
      final backup = await _getBackupBox();
      // 型なしBoxで開き直してデータを退避
      final rawBox = await Hive.openBox<dynamic>(boxName);
      _log('Raw backup: ${rawBox.length} entries found');

      if (rawBox.isNotEmpty) {
        await backup.put('keys', rawBox.keys.toList());
        await backup.put('count', rawBox.length);
        _log('Backup: keys=${rawBox.keys.toList()}, count=${rawBox.length}');
      }
      await rawBox.close();
    } catch (e) {
      _log('Raw backup failed: $e');
    }
  }

  @override
  Future<void> savePlayer(Player player) async {
    _log('Saving player (Lv.${player.level}, coins=${player.coins}, '
        'job=${player.currentJob})');
    final box = await _getBox();
    final backup = await _getBackupBox();

    // v1.6: 保存前に現在のキーセットをバックアップ
    try {
      await backup.put('keys', box.keys.toList());
      await backup.put('count', box.length);
      _log('Backup saved: keys=${box.keys.toList()}, count=${box.length}');
    } catch (e) {
      _log('Backup write failed (non-fatal): $e');
    }

    await box.put(0, player);
    await box.flush();
    // 読み戻して確認
    final verify = box.getAt(0);
    _log('Saved & flushed. Verify: Lv.${verify?.level}, coins=${verify?.coins}');

    // 保存成功後、バックアップをクリア
    try {
      await backup.clear();
      _log('Backup cleared after successful save');
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
    if (_backupBox != null && _backupBox!.isOpen) {
      await _backupBox!.close();
      _backupBox = null;
    }
  }
}
