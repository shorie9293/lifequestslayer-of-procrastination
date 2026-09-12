import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player;
  _MockPlayerRepo([Player? player]) : _player = player ?? Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

Widget _host(PlayerViewModel vm) => MaterialApp(
      home: ChangeNotifierProvider<PlayerViewModel>.value(
        value: vm,
        child: const TempleScreen(),
      ),
    );

/// ListView の遅延描画で下方カードが未構築にならないよう縦長ビューポートを設定。
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('TempleScreen — 修行の道標', () {
    testWidgets('初期プレイヤー: セクション表示・0/10・次の技は解放不可', (tester) async {
      _useTallViewport(tester);
      final vm = PlayerViewModel(_MockPlayerRepo())..load();
      await tester.pumpWidget(_host(vm));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.templeProgressionSection), findsOneWidget);
      expect(find.textContaining('スキル 0/10'), findsOneWidget);
      expect(find.textContaining('残りポイント 0'), findsOneWidget);
      // 次に解放できる技: 侍・一閃（2pt）等が3ツリー分表示
      expect(find.text('侍・一閃（2pt）'), findsOneWidget);
      expect(find.text('あと2pt'), findsNWidgets(3));
      expect(find.text('法師・祈り（2pt）'), findsOneWidget);
      expect(find.text('陰陽師・先見（2pt）'), findsOneWidget);
    });

    testWidgets('ポイント2で一閃が解放可能表示', (tester) async {
      _useTallViewport(tester);
      final vm = PlayerViewModel(
          _MockPlayerRepo(Player(skillPoints: 2)))
        ..load();
      await tester.pumpWidget(_host(vm));
      await tester.pumpAndSettle();

      expect(find.text('解放可能'), findsWidgets);
      expect(find.text('あと2pt'), findsNothing);
    });

    testWidgets('ジョブ進捗バー: 4ジョブ分が表示・浪人Lv10で習得済み', (tester) async {
      _useTallViewport(tester);
      final vm = PlayerViewModel(_MockPlayerRepo(Player(jobLevels: {
        Job.adventurer: 10,
        Job.samurai: 1,
        Job.monk: 1,
        Job.mystic: 1,
      })))
        ..load();
      await tester.pumpWidget(_host(vm));
      await tester.pumpAndSettle();

      for (final job in Job.values) {
        expect(
            find.byKey(AppKeys.templeProgressionJobBar(job)), findsOneWidget,
            reason: 'job ${job.name} の進捗バー');
      }
      expect(find.text('習得済み'), findsOneWidget); // 浪人のみ
      expect(find.textContaining('習得まであと'), findsNWidgets(3));
    });

    testWidgets('全ノード解放済みで完成メッセージ', (tester) async {
      _useTallViewport(tester);
      final vm = PlayerViewModel(_MockPlayerRepo(Player(
        skillPoints: 0,
        unlockedSkillIds: [
          'war_flash', 'war_combo', 'war_critical', 'war_zanshin',
          'cle_prayer', 'cle_heal', 'cle_ward',
          'wiz_foresight', 'wiz_split', 'wiz_transfer',
        ],
      )))
        ..load();
      await tester.pumpWidget(_host(vm));
      await tester.pumpAndSettle();

      expect(find.textContaining('スキル 10/10'), findsOneWidget);
      expect(find.text('全ての技を極めた！'), findsOneWidget);
      // pt不足表示（あとNpt）はスキル側に存在しない（ジョブ行の「習得まであとN」は別軸）。
      expect(find.textContaining('あと'), findsNWidgets(4)); // ジョブ習得進捗4行分のみ
      expect(find.textContaining('pt'), findsNothing);
    });
  });
}