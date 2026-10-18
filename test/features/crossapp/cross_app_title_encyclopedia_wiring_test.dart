// クロスアプリ称号図鑑への導線（町画面 TitleSection → 図鑑画面）試練。
//
// TitleSection の見出し右端の導線ボタンが実在し、タップで
// CrossAppTitleEncyclopediaScreen へ遷移して獲得済み称号名が表示されることを検証する。
// Hive 未初期化zone汚染を避けるため、既存のPlayerViewModel試練と同じく
// フェイクリポジトリを注入して Provider を構築する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/presentation/widgets/title_section.dart';

class _FakePlayerRepository implements IPlayerRepository {
  final Player player;
  _FakePlayerRepository(this.player);

  @override
  Future<Player?> loadPlayer() async => player;

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  Future<void> close() async {}

  @override
  bool get loadFailedDueToCorruption => false;
}

Future<void> _pumpTitleSection(
  WidgetTester tester, {
  required List<String> titles,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final player = Player(titles: titles);
  final vm = PlayerViewModel(_FakePlayerRepository(player));
  await tester.runAsync(() => vm.load());

  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: TitleSection(player: player, viewModel: vm),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('TitleSection に図鑑導線ボタンが存在する', (tester) async {
    await _pumpTitleSection(tester, titles: const ['読書家の卵']);
    expect(
      find.byKey(AppKeys.crossAppTitleEncyclopediaEntry),
      findsOneWidget,
    );
  });

  testWidgets('導線ボタンのタップで図鑑画面へ遷移し獲得称号名が表示される', (tester) async {
    await _pumpTitleSection(tester, titles: const ['読書家の卵']);

    await tester.tap(find.byKey(AppKeys.crossAppTitleEncyclopediaEntry));
    await tester.pumpAndSettle();

    expect(
      find.byKey(AppKeys.crossAppTitleEncyclopediaScreen),
      findsOneWidget,
    );
    expect(find.byKey(AppKeys.crossAppTitleSummary), findsOneWidget);
    expect(find.text('獲得 1 / 11'), findsOneWidget);
    expect(find.text('読書家の卵'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('複数の獲得称号が図鑑に反映される', (tester) async {
    await _pumpTitleSection(
      tester,
      titles: const ['読書家の卵', '書庫の冒険者', '知識の探求者'],
    );

    await tester.tap(find.byKey(AppKeys.crossAppTitleEncyclopediaEntry));
    await tester.pumpAndSettle();

    expect(find.text('獲得 3 / 11'), findsOneWidget);
    expect(find.text('書庫の冒険者'), findsOneWidget);
    expect(find.text('知識の探求者'), findsOneWidget);
  });
}
