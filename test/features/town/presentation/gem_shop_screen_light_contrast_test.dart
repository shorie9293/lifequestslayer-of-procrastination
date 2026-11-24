// ライトテーマ実描画のコントラスト走査（宝石ショップ）。
//
// 商品カード・両替カードの黒半透明を GamePalette トークンへ差し替えた結果、
// 和紙白（#F7F3E8）背景に対して読めない文字が 0 件であることを実描画から撃つ。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/town/presentation/gem_shop_screen.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player(coins: 5000, gems: 120);
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

/// 商品4種を返すIAPServiceモック（プラットフォームチャネル不要）。
class _MockIAPService extends IAPService {
  static final List<ProductDetails> _products = [
    ProductDetails(
      id: 'gems_tier1',
      title: '100 gems',
      description: '100 gems',
      price: '¥160',
      rawPrice: 160,
      currencyCode: 'JPY',
    ),
    ProductDetails(
      id: 'gems_tier2',
      title: '550 gems',
      description: '550 gems',
      price: '¥800',
      rawPrice: 800,
      currencyCode: 'JPY',
    ),
    ProductDetails(
      id: 'gems_tier3',
      title: '1200 gems',
      description: '1200 gems',
      price: '¥1,600',
      rawPrice: 1600,
      currencyCode: 'JPY',
    ),
    ProductDetails(
      id: 'gems_tier4',
      title: '2600 gems',
      description: '2600 gems',
      price: '¥3,200',
      rawPrice: 3200,
      currencyCode: 'JPY',
    ),
  ];

  @override
  bool get available => true;
  @override
  bool get loading => false;
  @override
  List<ProductDetails> get products => _products;
  @override
  String? get errorMessage => null;

  @override
  Future<int> consumePendingGems() async => 0;

  @override
  void clearError() {}
}

// ── 走査ハーネス（他担当と共用しない。各試練ファイルへ複製する） ──

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _effectiveBackground(Element element, Color scaffoldColor) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox) {
      final d = widget.decoration;
      if (d is BoxDecoration && d.color != null) layers.add(d.color!);
    } else if (widget is ColoredBox) {
      layers.add(widget.color);
    } else if (widget is Material && widget.color != null) {
      layers.add(widget.color!);
    } else if (widget is RawChip && widget.backgroundColor != null) {
      // Chip の背景は Material.color ではなく _RenderChip.paint が描く
      // （SDK chip.dart:1404 の Material は color を渡さない）ため、ここで拾う。
      layers.add(widget.backgroundColor!);
    }
    return true;
  });
  var bg = scaffoldColor;
  for (final layer in layers.reversed) {
    bg = Color.alphaBlend(layer, bg);
  }
  return bg;
}

bool _measurable(String text) =>
    RegExp(r'[0-9A-Za-z\u3040-\u30FF\u4E00-\u9FFF]').hasMatch(text);

class _Scan {
  int measurable = 0;
  int violations = 0;
  double minRatio = 99;
  String worst = '';
  final Set<int> colors = <int>{};

  @override
  String toString() => 'measurable=$measurable violations=$violations '
      'min=${minRatio.toStringAsFixed(2)}:1 ($worst)';
}

_Scan _scan(WidgetTester tester) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final scaffold = app.theme!.scaffoldBackgroundColor;
  final fallback = app.theme!.textTheme.bodyMedium?.color ?? Colors.black;
  final scan = _Scan();
  final counted = <String>{};
  for (final element in tester.allElements) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph) continue;
    if (ro.debugNeedsLayout) continue;
    final plain = ro.text.toPlainText();
    if (!_measurable(plain)) continue;
    final bg = _effectiveBackground(element, scaffold);
    final raw = ro.text.style?.color ?? fallback;
    final eff = Color.alphaBlend(raw, bg);
    final ratio = _contrast(eff, bg);
    scan.measurable++;
    scan.colors.add(raw.toARGB32());
    if (ratio < scan.minRatio) {
      scan.minRatio = ratio;
      scan.worst = '"$plain"';
    }
    if (ratio < 3.0 && counted.add(plain)) scan.violations++;
  }
  return scan;
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  final playerVM = PlayerViewModel(_MockPlayerRepo());
  await playerVM.load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<ShopViewModel>(
            create: (_) => ShopViewModel(playerVM)),
        ChangeNotifierProvider<IAPService>.value(value: _MockIAPService()),
      ],
      child: MaterialApp(theme: theme, home: const GemShopScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('宝石ショップ: ライト実描画で 3.0:1 未満が 0 件', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.lightForJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('GEMSHOP LIGHT $scan');
    expect(scan.measurable, greaterThanOrEqualTo(12),
        reason: '走査母数が少なすぎる＝空振りで緑になっている疑い');
    expect(scan.violations, 0, reason: 'ライトで読めない文字: $scan');
  });

  testWidgets('宝石ショップ: ダークは墨色へ退行していない', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, GameThemes.forJob(Job.adventurer));
    final scan = _scan(tester);
    // ignore: avoid_print
    print('GEMSHOP DARK $scan');
    expect(scan.violations, 0, reason: 'ダークで読めない文字: $scan');
    expect(scan.measurable, greaterThanOrEqualTo(12));
    for (final argb in const [0xFF2B2B2B, 0xFF4A4A4A, 0xFF5A5A5A, 0xFF6B6B6B]) {
      expect(scan.colors.contains(argb), isFalse,
          reason: 'ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
    }
  });
}
