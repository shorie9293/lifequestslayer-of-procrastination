import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Play Console に登録する商品ID（消耗型）
const kGemProducts = <String, int>{
  'gems_tier1': 100,   // 100宝石  ¥120
  'gems_tier2': 550,   // 550宝石  ¥490  (+50ボーナス)
  'gems_tier3': 1200,  // 1200宝石 ¥980  (+200ボーナス)
  'gems_tier4': 2600,  // 2600宝石 ¥1,960 (+600ボーナス)
};

const _kPendingBoxName = 'iapPendingBox';
const _kPendingKey = 'pendingGems';

class IAPService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Box? _pendingBox;

  bool _available = false;
  bool _loading = true;
  List<ProductDetails> _products = [];
  String? _errorMessage;
  int _pendingGems = 0; // 購入完了済みで未付与の宝石数（Hiveに永続化）
  bool _isConsuming = false; // 二重消費防止フラグ

  bool get available => _available;
  bool get loading => _loading;
  List<ProductDetails> get products => _products;
  String? get errorMessage => _errorMessage;
  int get pendingGems => _pendingGems;

  Future<void> initialize() async {
    // 未付与宝石をHiveから復元（クラッシュ後の保護）
    _pendingBox = await Hive.openBox(_kPendingBoxName);
    _pendingGems = _pendingBox?.get(_kPendingKey, defaultValue: 0) as int? ?? 0;

    _available = await _iap.isAvailable();
    if (!_available) {
      _loading = false;
      notifyListeners();
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(kGemProducts.keys.toSet());
    if (response.error != null) {
      _errorMessage = response.error!.message;
    }
    _products = response.productDetails
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    _loading = false;
    notifyListeners();
  }

  /// 宝石パックを購入する（消耗型）
  void buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final gems = kGemProducts[purchase.productID] ?? 0;
          if (gems > 0) {
            _pendingGems += gems;
            // completePurchase より先に永続化して、クラッシュ時の未付与を防ぐ
            await _pendingBox?.put(_kPendingKey, _pendingGems);
            notifyListeners();
          }
          await _iap.completePurchase(purchase);
        case PurchaseStatus.error:
          _errorMessage = purchase.error?.message ?? '購入エラーが発生しました';
          notifyListeners();
          await _iap.completePurchase(purchase);
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  /// UIが呼び出して宝石をGameViewModelに付与する
  /// 二重消費防止のため atomic に処理する
  Future<int> consumePendingGems() async {
    if (_isConsuming) return 0;
    _isConsuming = true;
    try {
      final gems = _pendingGems;
      if (gems <= 0) return 0;
      _pendingGems = 0;
      await _pendingBox?.put(_kPendingKey, 0);
      return gems;
    } finally {
      _isConsuming = false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
