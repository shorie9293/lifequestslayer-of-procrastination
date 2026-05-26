import 'package:get_it/get_it.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // ── リポジトリ ──
  final playerRepo = PlayerRepository();
  final taskRepo = TaskRepository();
  final settingsRepo = SettingsRepository();

  getIt.registerSingleton<IPlayerRepository>(playerRepo);
  getIt.registerSingleton<ITaskRepository>(taskRepo);
  getIt.registerSingleton<SettingsRepository>(settingsRepo);

  // ── ViewModels（依存順に登録） ──
  final playerVM = PlayerViewModel(playerRepo);
  getIt.registerSingleton<PlayerViewModel>(playerVM);

  final taskVM = TaskViewModel(taskRepo, playerVM);
  getIt.registerSingleton<TaskViewModel>(taskVM);

  final shopVM = ShopViewModel(playerVM);
  getIt.registerSingleton<ShopViewModel>(shopVM);

  final settingsVM = SettingsViewModel(settingsRepo);
  getIt.registerSingleton<SettingsViewModel>(settingsVM);

  final themeVM = ThemeViewModel(playerVM);
  getIt.registerSingleton<ThemeViewModel>(themeVM);

  // ── サービス ──
  final iapService = IAPService();
  getIt.registerSingleton<IAPService>(iapService);
}
