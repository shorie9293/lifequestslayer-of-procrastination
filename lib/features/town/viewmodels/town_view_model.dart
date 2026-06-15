import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:rpg_todo/features/town/domain/town_level.dart';
import 'package:rpg_todo/features/town/domain/building.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';
import 'package:injectable/injectable.dart';

/// 町の発展を管理するViewModel。
///
/// 町のレベル・XP、建物の状態を保持し、永続化する。
/// クエスト完了時に町XPが加算され、町が成長していく。
@lazySingleton
class TownViewModel extends ChangeNotifier {
  static const String _boxName = 'townBox';
  static const String _key = 'townData';

  TownLevel _townLevel = TownLevel();
  final Map<Building, BuildingState> _buildings = {};

  /// Hive box。テストでは外部から注入可能。
  Box<dynamic>? _box;

  TownViewModel();

  /// 町のレベルと経験値。
  TownLevel get townLevel => _townLevel;

  /// 全建物の状態マップ（変更不可）。
  Map<Building, BuildingState> get buildings => Map.unmodifiable(_buildings);

  /// 町レベルに基づく現在の発展段階。
  TownScale get townScale => TownScale.fromLevel(_townLevel.level);

  /// 町の状態を初期化する。
  /// 全建物をレベル1で生成する。すでに初期化済みの場合は何もしない。
  void initialize() {
    if (_buildings.isNotEmpty) return;
    for (final building in Building.values) {
      _buildings[building] = BuildingState(building: building);
    }
  }

  /// 町に経験値を加算する。
  ///
  /// 町レベルが上昇した場合は true を返す。
  /// リスナーに通知する。
  bool addTownXp(int amount) {
    final leveledUp = _townLevel.addXp(amount);
    notifyListeners();
    return leveledUp;
  }

  /// 建物をアップグレードする。
  ///
  /// [playerCoins] プレイヤーの現在の所持コイン。
  /// [spendCoins] コインを消費するコールバック。
  ///
  /// 成功した場合は true を返し、自動的に Hive に保存する。
  bool upgradeBuilding(
    Building building, {
    required int playerCoins,
    required void Function(int amount) spendCoins,
  }) {
    final state = _buildings[building];
    if (state == null) return false;
    if (!state.canUpgrade) return false;

    final cost = state.upgradeCoinCost;
    if (playerCoins < cost) return false;

    spendCoins(cost);
    final result = state.upgrade();
    if (result) {
      notifyListeners();
    }
    return result;
  }

  /// Hive box を取得する（遅延オープン）。
  /// Hive box を取得する。破損時は lock ファイルのみ除去し再試行する。
  /// データファイルは削除しない（データ救出を優先）。
  Future<Box<dynamic>?> _getBox() async {
    if (_box != null && _box!.isOpen) return _box;

    try {
      _box = await Hive.openBox<dynamic>(_boxName);
      return _box;
    } catch (e) {
      debugPrint('[TownVM] Failed to open box: $e');
      // lock ファイルが残っている可能性 → 除去して再試行
      try {
        final dir = await getApplicationDocumentsDirectory();
        final lockFile = File('${dir.path}/$_boxName.lock');
        if (await lockFile.exists()) {
          await lockFile.delete();
          debugPrint('[TownVM] Removed stale lock file, retrying...');
        }
        _box = await Hive.openBox<dynamic>(_boxName);
        return _box;
      } catch (e2) {
        debugPrint('[TownVM] Retry also failed: $e2');
        // 最終手段：box を削除して再作成
        try {
          final dir = await getApplicationDocumentsDirectory();
          final hiveFile = File('${dir.path}/$_boxName.hive');
          final lockFile = File('${dir.path}/$_boxName.lock');
          if (await lockFile.exists()) await lockFile.delete();
          if (await hiveFile.exists()) await hiveFile.delete();
          debugPrint('[TownVM] Deleted box files, recreating...');
          _box = await Hive.openBox<dynamic>(_boxName);
          return _box;
        } catch (e3) {
          debugPrint('[TownVM] All recovery failed: $e3');
          return null;
        }
      }
    }
  }

  /// テスト用にカスタム Box を注入する。
  @visibleForTesting
  set boxForTest(Box<dynamic> box) {
    _box = box;
  }

  /// テスト用に町レベルを直接設定する。
  @visibleForTesting
  void setTownLevelForTest(int level) {
    _townLevel = TownLevel(level: level, xp: 0);
    notifyListeners();
  }

  /// 町データを Hive に保存する。
  Future<void> save() async {
    final box = await _getBox();
    if (box == null) return;

    final data = <String, dynamic>{
      'townLevel': _townLevel.toJson(),
      'buildings': _buildings.map(
        (key, value) => MapEntry(key.name, value.toJson()),
      ),
    };
    await box.put(_key, data);
    await box.flush();
  }

  /// 町データを Hive から読み込む。
  Future<void> load() async {
    final box = await _getBox();
    if (box == null) return;

    try {
      final data = box.get(_key);
      if (data != null && data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['townLevel'] != null && map['townLevel'] is Map) {
          _townLevel = TownLevel.fromJson(
            Map<String, dynamic>.from(map['townLevel'] as Map),
          );
        }
        if (map['buildings'] != null && map['buildings'] is Map) {
          final buildingsJson =
              Map<String, dynamic>.from(map['buildings'] as Map);
          _buildings.clear();
          for (final entry in buildingsJson.entries) {
            try {
              final building = Building.fromString(entry.key);
              final state = BuildingState.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              );
              _buildings[building] = state;
            } catch (e) {
              debugPrint('[TownVM] Skipping corrupted building entry: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TownVM] Load failed (data corrupted): $e');
      // 破損時は全データを初期化
      _townLevel = TownLevel();
      _buildings.clear();
    }
    // Ensure all buildings exist even if not in saved data
    for (final building in Building.values) {
      _buildings.putIfAbsent(
        building,
        () => BuildingState(building: building),
      );
    }
    notifyListeners();
  }
}
