import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:get_it/get_it.dart';

void main() {
  group('DI（依存性注入）試験', () {
    setUp(() async {
      // get_itをリセットしてcleanな状態から開始
      await GetIt.instance.reset();

      // 依存性を設定
      configureDependencies();
    });

    tearDown(() async {
      // 後始末
      await GetIt.instance.reset();
    });

    test('IPlayerRepositoryがシングルトンとして登録されている', () {
      final repo = getIt<IPlayerRepository>();
      expect(repo, isNotNull);
      // 同じインスタンスが返ることを確認
      final repo2 = getIt<IPlayerRepository>();
      expect(identical(repo, repo2), isTrue);
    });

    test('ITaskRepositoryがシングルトンとして登録されている', () {
      final repo = getIt<ITaskRepository>();
      expect(repo, isNotNull);
    });

    test('SettingsRepositoryがシングルトンとして登録されている', () {
      final repo = getIt<SettingsRepository>();
      expect(repo, isNotNull);
    });

    test('PlayerViewModelがシングルトンとして登録されている', () {
      final vm = getIt<PlayerViewModel>();
      expect(vm, isNotNull);
    });

    test('TaskViewModelがシングルトンとして登録されている（PlayerVM依存含む）', () {
      final taskVM = getIt<TaskViewModel>();
      expect(taskVM, isNotNull);

      // PlayerViewModelに依存していることを確認
      final playerVM = getIt<PlayerViewModel>();
      expect(playerVM, isNotNull);
    });

    test('ShopViewModelがシングルトンとして登録されている（PlayerVM依存含む）', () {
      final vm = getIt<ShopViewModel>();
      expect(vm, isNotNull);
    });

    test('SettingsViewModelがシングルトンとして登録されている', () {
      final vm = getIt<SettingsViewModel>();
      expect(vm, isNotNull);
    });

    test('ThemeViewModelがシングルトンとして登録されている（PlayerVM依存含む）', () {
      final vm = getIt<ThemeViewModel>();
      expect(vm, isNotNull);
    });

    test('IAPServiceがシングルトンとして登録されている', () {
      final service = getIt<IAPService>();
      expect(service, isNotNull);
      // 同じインスタンスが返ることを確認
      final service2 = getIt<IAPService>();
      expect(identical(service, service2), isTrue);
    });

    test('全VM・サービスが同一のgetItインスタンスから取得可能', () {
      // 全ての登録済みサービスが取得できることを一括確認
      expect(() => getIt<IPlayerRepository>(), returnsNormally);
      expect(() => getIt<ITaskRepository>(), returnsNormally);
      expect(() => getIt<SettingsRepository>(), returnsNormally);
      expect(() => getIt<PlayerViewModel>(), returnsNormally);
      expect(() => getIt<TaskViewModel>(), returnsNormally);
      expect(() => getIt<ShopViewModel>(), returnsNormally);
      expect(() => getIt<SettingsViewModel>(), returnsNormally);
      expect(() => getIt<ThemeViewModel>(), returnsNormally);
      expect(() => getIt<IAPService>(), returnsNormally);
    });
  });
}
