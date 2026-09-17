import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_badge_collection_screen.dart';

/// Hiveに触れないフェイクリポジトリ。
class _FakeReflectionRepository implements ReflectionRepository {
  final List<Reflection> reflections;

  _FakeReflectionRepository(this.reflections);

  @override
  Future<List<Reflection>> getAll() async => reflections;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 「リポジトリが利用できない」ケース（未初期化環境の想定）。
class _EmptyRepository implements ReflectionRepository {
  @override
  Future<List<Reflection>> getAll() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Reflection _r(DateTime date, {int self = 1, QuestRank ai = QuestRank.B}) {
  return Reflection(
    id: 'r_${date.millisecondsSinceEpoch}_${self}_$ai',
    taskId: 't1',
    date: date,
    content: '学び',
    selfDifficulty: self,
    aiDifficulty: ai,
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 50));
}

/// ListView の遅延描画対策: 縦長ビューポートを設定する。
/// (下方のtierセクションが未構築になり findsOneWidget が落ちるため)
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpWith(
  WidgetTester tester, {
  required Player player,
  required ReflectionRepository repository,
  bool withProvider = true,
}) async {
  _tallViewport(tester);
  final screen = ReflectionBadgeCollectionScreen(
    repository: repository,
    onBack: () {},
  );
  final Widget widget;
  if (withProvider) {
    final vm = PlayerViewModel(_FakePlayerRepository(player));
    // initState時点で player が反映済みであるよう事前ロード（runAsyncで実時間許可）
    await tester.runAsync(() => vm.load());
    widget = ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(home: screen),
    );
  } else {
    widget = MaterialApp(home: screen);
  }
  await _pump(tester, widget);
}

void main() {
  testWidgets('サマリーカードに「獲得 X / 12」が表示される', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf(['first_reflection']),
      repository: _FakeReflectionRepository([]),
    );
    expect(find.byKey(AppKeys.reflectionBadgeSummaryCard), findsOneWidget);
    expect(find.text('獲得 1 / 12'), findsOneWidget);
  });

  testWidgets('tier別セクション見出しが表示される', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf([]),
      repository: _FakeReflectionRepository([]),
    );
    expect(find.byKey(AppKeys.reflectionBadgeTierSection(1)), findsOneWidget);
    expect(find.byKey(AppKeys.reflectionBadgeTierSection(2)), findsOneWidget);
    expect(find.byKey(AppKeys.reflectionBadgeTierSection(3)), findsOneWidget);
    expect(find.byKey(AppKeys.reflectionBadgeTierSection(4)), findsOneWidget);
    expect(find.text('— ブロンズ —'), findsOneWidget);
    expect(find.text('— 伝説 —'), findsOneWidget);
  });

  testWidgets('未獲得バッジの条件説明が表示される', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf([]),
      repository: _FakeReflectionRepository([]),
    );
    expect(find.text('振り返りを5回記した'), findsOneWidget);
    expect(
      find.byKey(AppKeys.reflectionBadgeRow('reflection_novice')),
      findsOneWidget,
    );
  });

  testWidgets('獲得済みバッジは名前とチェックアイコンが表示される', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf(['first_reflection']),
      repository: _FakeReflectionRepository([]),
    );
    expect(find.text('初めての内省'), findsOneWidget);
    final row = tester.widget<KeyedSubtree>(
      find.byKey(AppKeys.reflectionBadgeRow('first_reflection')),
    );
    final opacity = (row.child as Opacity).opacity;
    expect(opacity, 1.0);
  });

  testWidgets('進捗ラベル（current / required）が表示される', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf([], totalReflections: 3),
      repository: _FakeReflectionRepository([]),
    );
    expect(find.text('3 / 5'), findsOneWidget);
  });

  testWidgets('空履歴・空バッジでも落ちない', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf([]),
      repository: _FakeReflectionRepository([]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(AppKeys.reflectionBadgeSummaryCard), findsOneWidget);
  });

  testWidgets('Provider が無い環境でも落ちない（引数注入のみで動作）', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf([]),
      repository: _FakeReflectionRepository([]),
      withProvider: false,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(AppKeys.reflectionBadgeSummaryCard), findsOneWidget);
  });

  testWidgets('振り返り履歴からstreak進捗が反映される', (tester) async {
    final now = DateTime(2026, 9, 10);
    final reflections = [
      _r(now),
      _r(now.subtract(const Duration(days: 1))),
      _r(now.subtract(const Duration(days: 2))),
    ];
    await _pumpWith(
      tester,
      player: _playerOf([]),
      repository: _FakeReflectionRepository(reflections),
    );
    // streak_3 の行に '3 / 3' が表示される（他バッジの同名表示と区別するため行に限定）
    expect(
      find.descendant(
        of: find.byKey(AppKeys.reflectionBadgeRow('streak_3')),
        matching: find.text('3 / 3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('画面rootにAppKeys.reflectionBadgeCollectionScreenが付く', (tester) async {
    await _pumpWith(
      tester,
      player: _playerOf([]),
      repository: _EmptyRepository(),
    );
    expect(
      find.byKey(AppKeys.reflectionBadgeCollectionScreen),
      findsOneWidget,
    );
  });
}

Player _playerOf(List<String> badges, {int totalReflections = 0}) =>
    Player(totalReflections: totalReflections, reflectionBadges: badges);

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
