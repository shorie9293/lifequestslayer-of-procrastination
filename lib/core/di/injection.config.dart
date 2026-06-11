// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;

import 'package:rpg_todo/domain/repositories/i_player_repository.dart' as _i3;
import 'package:rpg_todo/domain/repositories/i_task_repository.dart' as _i4;
import 'package:rpg_todo/features/shared/data/player_repository.dart' as _i5;
import 'package:rpg_todo/features/guild/data/task_repository.dart' as _i6;
import 'package:rpg_todo/features/shared/data/settings_repository.dart' as _i7;
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart' as _i8;
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart' as _i9;
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart' as _i10;
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart' as _i11;
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart' as _i12;
import 'package:rpg_todo/core/infrastructure/iap_service.dart' as _i13;

/// initializes the registration of main-scope dependencies inside of [GetIt]
_i1.GetIt initGetIt(
  _i1.GetIt getIt, {
  String? environment,
  _i2.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i2.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );

  // ── Repositories (no dependencies on other registered types) ──
  gh.lazySingleton<_i3.IPlayerRepository>(() => _i5.PlayerRepository());
  gh.lazySingleton<_i4.ITaskRepository>(() => _i6.TaskRepository());
  gh.lazySingleton<_i7.SettingsRepository>(() => _i7.SettingsRepository());

  // ── Services ──
  gh.lazySingleton<_i13.IAPService>(() => _i13.IAPService());

  // ── ViewModels (ordered by dependency chain) ──
  gh.lazySingleton<_i8.PlayerViewModel>(
      () => _i8.PlayerViewModel(gh<_i3.IPlayerRepository>()));
  gh.lazySingleton<_i9.TaskViewModel>(
      () => _i9.TaskViewModel(gh<_i4.ITaskRepository>(), gh<_i8.PlayerViewModel>()));
  gh.lazySingleton<_i10.ShopViewModel>(
      () => _i10.ShopViewModel(gh<_i8.PlayerViewModel>()));
  gh.lazySingleton<_i11.SettingsViewModel>(
      () => _i11.SettingsViewModel(gh<_i7.SettingsRepository>()));
  gh.lazySingleton<_i12.ThemeViewModel>(
      () => _i12.ThemeViewModel(gh<_i8.PlayerViewModel>()));

  return getIt;
}
