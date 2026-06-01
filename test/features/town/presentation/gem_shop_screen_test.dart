import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';
import 'package:rpg_todo/features/town/presentation/gem_shop_screen.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// PlayerRepositoryモック
class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

/// IAPServiceモック (platform channel不要)
class _MockIAPService extends IAPService {
  @override
  bool get available => false;
  @override
  bool get loading => false;
  @override
  List<ProductDetails> get products => [];
  @override
  String? get errorMessage => null;

  @override
  Future<int> consumePendingGems() async => 0;

  @override
  void clearError() {}
}

void main() {
  group('GemShopScreen — Bug UX-11: Back button', () {
    late PlayerViewModel playerVM;
    late ShopViewModel shopVM;
    late _MockIAPService iap;

    setUp(() {
      playerVM = PlayerViewModel(_MockPlayerRepo());
      shopVM = ShopViewModel(playerVM);
      iap = _MockIAPService();
    });

    testWidgets('AppBarに戻るボタン(BackButton)が存在する', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
            ChangeNotifierProvider<ShopViewModel>.value(value: shopVM),
            ChangeNotifierProvider<IAPService>.value(value: iap),
          ],
          child: const MaterialApp(
            home: GemShopScreen(),
          ),
        ),
      );

      await tester.pump();

      // GemShopScreenが表示されている
      expect(find.byKey(AppKeys.gemShopScreen), findsOneWidget);

      // BackButtonが存在する
      expect(find.byType(BackButton), findsOneWidget);

      // AppBarのタイトルが正しい
      expect(find.text('💎 宝石ショップ'), findsOneWidget);
    });
  });
}
