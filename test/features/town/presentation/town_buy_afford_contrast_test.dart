// 買える状態（金地 #FFA000）の前景コントラスト走査。
//
// 町タブの走査ハーネスは硬貨0のプレイヤーを組むため「買えない（灰地）」しか
// 描画されず、金地に白文字が載る退行を検出できない。ここでは硬貨を十分に持つ
// プレイヤーで購入ボタン／宿屋ボタンを実描画し、金地の前景を撃つ。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/town/presentation/widgets/inn_section.dart';
import 'package:rpg_todo/features/town/presentation/widgets/shop_item.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  final Player _player;
  _MockPlayerRepository(this._player);

  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 金地のボタンを実描画し、解決後の前景/背景の比を返す。
Future<List<(String, double)>> _measure(WidgetTester tester,
    {required ThemeData theme, required int coins}) async {
  final player = Player(coins: coins);
  final playerVM = PlayerViewModel(_MockPlayerRepository(player));
  await tester.runAsync(() => playerVM.load());
  final shopVM = ShopViewModel(playerVM);
  const item = ShopItem(id: 'probe', name: '品', price: 50, description: '説明');

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              buildBuyButton(context, player, shopVM, item),
              InnSection(player: player, viewModel: shopVM),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final results = <(String, double)>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! ElevatedButton) continue;
    final bg = widget.style?.backgroundColor?.resolve(<WidgetState>{});
    final fg = widget.style?.foregroundColor?.resolve(<WidgetState>{});
    if (bg == null || fg == null) continue;
    final effFg = Color.alphaBlend(fg, bg);
    results.add((
      'fg=${fg.toARGB32().toRadixString(16)} bg=${bg.toARGB32().toRadixString(16)}',
      _contrast(effFg, bg),
    ));
  }
  return results;
}

void main() {
  for (final entry in <(String, ThemeData)>[
    ('ライト', GameThemes.lightForJob(Job.adventurer)),
    ('ダーク', GameThemes.forJob(Job.adventurer)),
  ]) {
    testWidgets('${entry.$1}: 買える時の金地ボタンが 3.0:1 以上', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final measured = await _measure(tester, theme: entry.$2, coins: 999999);
      expect(measured, isNotEmpty, reason: 'ボタンが1つも描画されていない＝空振り');
      for (final (desc, ratio) in measured) {
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: '${entry.$1}の金地ボタンが読めない: $desc → '
                '${ratio.toStringAsFixed(2)}:1');
      }
    });
  }
}
