// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../domain/repositories/i_player_repository.dart' as _i1020;
import '../../domain/repositories/i_task_repository.dart' as _i367;
import '../../features/guild/data/task_repository.dart' as _i968;
import '../../features/guild/viewmodels/task_view_model.dart' as _i503;
import '../../features/player/viewmodels/player_view_model.dart' as _i779;
import '../../features/shared/data/player_repository.dart' as _i664;
import '../../features/shared/data/settings_repository.dart' as _i102;
import '../../features/shared/viewmodels/settings_view_model.dart' as _i474;
import '../../features/shared/viewmodels/theme_view_model.dart' as _i417;
import '../../features/town/viewmodels/shop_view_model.dart' as _i494;
import '../infrastructure/iap_service.dart' as _i960;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  gh.lazySingleton<_i102.SettingsRepository>(() => _i102.SettingsRepository());
  gh.lazySingleton<_i960.IAPService>(() => _i960.IAPService());
  gh.lazySingleton<_i1020.IPlayerRepository>(() => _i664.PlayerRepository());
  gh.lazySingleton<_i779.PlayerViewModel>(
      () => _i779.PlayerViewModel(gh<_i1020.IPlayerRepository>()));
  gh.lazySingleton<_i494.ShopViewModel>(
      () => _i494.ShopViewModel(gh<_i779.PlayerViewModel>()));
  gh.lazySingleton<_i417.ThemeViewModel>(
      () => _i417.ThemeViewModel(gh<_i779.PlayerViewModel>()));
  gh.lazySingleton<_i367.ITaskRepository>(() => _i968.TaskRepository());
  gh.lazySingleton<_i503.TaskViewModel>(() => _i503.TaskViewModel(
        gh<_i367.ITaskRepository>(),
        gh<_i779.PlayerViewModel>(),
      ));
  gh.lazySingleton<_i474.SettingsViewModel>(
      () => _i474.SettingsViewModel(gh<_i102.SettingsRepository>()));
  return getIt;
}
