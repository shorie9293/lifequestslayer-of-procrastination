import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

void main() {
  group('ThemeViewModel', () {
    test('initial theme is adventurer', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final themeVm = ThemeViewModel(playerVm);
      expect(themeVm.currentTheme, GameThemes.forJob(Job.adventurer));
    });

    test('theme changes when job changes', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final themeVm = ThemeViewModel(playerVm);
      playerVm.changeJob(Job.samurai, debugMode: true);
      expect(themeVm.currentTheme, GameThemes.forJob(Job.samurai));
    });
  });
}
