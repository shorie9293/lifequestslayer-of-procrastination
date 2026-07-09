import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';

import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';

import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'package:rpg_todo/features/guild/data/supabase_task_repository.dart';
import 'package:rpg_todo/features/shared/data/supabase_player_repository.dart';
import 'package:rpg_todo/features/guild/data/hybrid_task_repository.dart';
import 'package:rpg_todo/features/shared/data/hybrid_player_repository.dart';
import 'package:rpg_todo/core/infrastructure/supabase_config.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'initGetIt',
  preferRelativeImports: true,
  asExtension: false,
)
void configureDependencies() {
  initGetIt(getIt);

  // ━━━ Supabase ハイブリッドリポジトリ切替 ━━━
  if (SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty) {
    try {
      getIt.allowReassignment = true;

      getIt.registerLazySingleton<ITaskRepository>(() => HybridTaskRepository(
            hiveRepo: TaskRepository(),
            supabaseRepo:
                SupabaseTaskRepository(Supabase.instance.client),
          ));

      getIt.registerLazySingleton<IPlayerRepository>(() => HybridPlayerRepository(
            hiveRepo: PlayerRepository(),
            supabaseRepo:
                SupabasePlayerRepository(Supabase.instance.client),
          ));

      debugPrint('[DI] ✅ Supabaseハイブリッドリポジトリに切替完了');
    } catch (e) {
      debugPrint('[DI] ⚠️ ハイブリッド切替失敗（Hiveのみ継続）: $e');
    }
  }

  // 戦闘系サービス（injectable未対応のため手動登録）
  getIt.registerLazySingleton<BattleAudioService>(() => BattleAudioService());
  getIt.registerLazySingleton<BattleViewModel>(() => BattleViewModel());

  // 町開発 ViewModel（Hive box に依存するため手動登録）
  getIt.registerLazySingleton<TownViewModel>(() => TownViewModel());

  // 全VM統括 GameViewModel（getItのVMを注入、二重構造解消）
  getIt.registerLazySingleton<GameViewModel>(() => GameViewModel(
    playerVM: getIt<PlayerViewModel>(),
    taskVM: getIt<TaskViewModel>(),
    shopVM: getIt<ShopViewModel>(),
    settingsVM: getIt<SettingsViewModel>(),
    themeVM: getIt<ThemeViewModel>(),
    tv: getIt<TownViewModel>(),
    autoLoad: false,  // initializeViewModels() でロード済みのため
  ));
}

/// 全VMのデータロードとアプリライフサイクル監視を統括する。
/// main()内で configureDependencies() の後に呼ぶこと。
Future<void> initializeViewModels() async {
  final playerVM = getIt<PlayerViewModel>();
  final taskVM = getIt<TaskViewModel>();
  final settingsVM = getIt<SettingsViewModel>();
  final townVM = getIt<TownViewModel>();

  await playerVM.load();
  await taskVM.load();
  await settingsVM.load();
  await townVM.load();
  townVM.initialize();

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
        await townVM.save().catchError((e) => debugPrint('[DI] town save failed: $e'));
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
