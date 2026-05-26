import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/services/fatigue_service.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

/// ショップ・宿屋・宝石関連の操作を管理するViewModel
class ShopViewModel extends ChangeNotifier {
  final PlayerViewModel _playerVM;

  ShopViewModel(this._playerVM);

  bool get isDebugMode => false; // managed by SettingsVM

  // ── 宝石操作 ──
  bool spendGems(int amount, {bool debugMode = false}) {
    final result = _playerVM.spendGems(amount, debugMode: debugMode);
    if (result) notifyListeners();
    return result;
  }

  bool exchangeGemsForCoins(int amount, {bool debugMode = false}) {
    if (debugMode) {
      _playerVM.addCoins(amount * 100);
      notifyListeners();
      return true;
    }
    if (!_playerVM.spendGems(amount, debugMode: debugMode)) return false;
    _playerVM.addCoins(amount * 100);
    notifyListeners();
    return true;
  }

  bool resetFatigueWithGems({bool debugMode = false}) {
    if (debugMode) {
      _playerVM.setDailyTasksCompleted(0);
      notifyListeners();
      return true;
    }
    if (!_playerVM.spendGems(50, debugMode: debugMode)) return false;
    _playerVM.setDailyTasksCompleted(0);
    notifyListeners();
    return true;
  }

  // ── 宿屋 ──
  String? restAtInn(int tier, {bool debugMode = false}) {
    if (debugMode) {
      _playerVM.setNextDayTaskLimitOffset(tier == 2 ? 12 : tier == 1 ? 5 : 2);
      notifyListeners();
      return null;
    }
    final r = FatigueService.restAtInn(_playerVM.player, tier, DateTime.now());
    if (r == null) notifyListeners();
    return r;
  }

  // ── ショップ購入 ──
  bool buyShopItem(String id, int price, {bool debugMode = false}) {
    final result = _playerVM.buyHomeItem(id, price, debugMode: debugMode);
    if (result) notifyListeners();
    return result;
  }
}
