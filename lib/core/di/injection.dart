import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

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

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'initGetIt',
  preferRelativeImports: true,
  asExtension: false,
)
void configureDependencies() => initGetIt(getIt);

/// 全VMのデータロードとアプリライフサイクル監視を統括する。
/// main()内で configureDependencies() の後に呼ぶこと。
Future<void> initializeViewModels() async {
  final playerVM = getIt<PlayerViewModel>();
  final taskVM = getIt<TaskViewModel>();
  final settingsVM = getIt<SettingsViewModel>();

  await playerVM.load();
  await taskVM.load();
  await settingsVM.load();

  // ★ v1.6: PlayerRepositoryへのアクセス
  final playerRepo = getIt<IPlayerRepository>();

  try {
    // ignore: avoid_print
    print('[DI] Before missions: Lv.${playerVM.player.level}, coins=${playerVM.player.coins}');

    // ★ v1.6: デシリアライズ失敗時は旧データを上書きしない
    if (playerRepo.loadFailedDueToCorruption) {
      // ignore: avoid_print
      print('[DI] ⚠️ Player data corruption detected — SKIPPING save to preserve backup data');
      // ミッション処理もスキップ（デフォルトPlayerに対して実行する意味がない）
      // ignore: avoid_print
      print('[DI] User should see "data recovery needed" message on next UI');
    } else {
      playerVM.checkAndResetMissions(DateTime.now(), login: true);
      // ignore: avoid_print
      print('[DI] After missions: Lv.${playerVM.player.level}, coins=${playerVM.player.coins}');
      await playerVM.save();
      // ignore: avoid_print
      print('[DI] Player saved after missions');
    }
  } catch (e, s) {
    debugPrint('[DI] missions error: $e\n$s');
  }

  try {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
      onPause: () async {
        await _safeSave(playerVM, 'player');
        await _safeSave(taskVM, 'task');
      },
    ));
  } catch (_) {}

  try {
    taskVM.autoDeployTodaysTasks();
  } catch (e, s) {
    debugPrint('[DI] autoDeploy error: $e\n$s');
  }
}

Future<void> _safeSave(ChangeNotifier vm, String label) async {
  if (vm is PlayerViewModel) {
    // ★ v1.6: corruption時は旧データを上書きしない
    final repo = getIt<IPlayerRepository>();
    if (repo.loadFailedDueToCorruption) {
      debugPrint('[DI] Skipping $label save (corruption detected)');
      return;
    }
    await vm.save().catchError((e) => debugPrint('[DI] $label save failed: $e'));
  } else if (vm is TaskViewModel) {
    await vm.save().catchError((e) => debugPrint('[DI] $label save failed: $e'));
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final Future<void> Function() _onPause;
  _AppLifecycleObserver({required Future<void> Function() onPause})
      : _onPause = onPause;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _onPause();
    }
  }
}
