import 'package:flutter/material.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:injectable/injectable.dart';

/// ジョブに応じたテーマを提供するViewModel
@lazySingleton
class ThemeViewModel extends ChangeNotifier {
  final PlayerViewModel _playerVM;

  ThemeViewModel(this._playerVM) {
    _playerVM.addListener(() => notifyListeners());
  }

  ThemeData get currentTheme => GameThemes.forJob(_playerVM.player.currentJob);

  @override
  void dispose() {
    _playerVM.removeListener(() => notifyListeners()); // best-effort
    super.dispose();
  }
}
