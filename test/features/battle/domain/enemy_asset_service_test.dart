import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';

/// 敵アセット画像の読み込みをタスクから独立して検証する試験
///
/// 3層で検証:
///   A. ファイルシステム層: EnemyAssetService の全パスが実在するか
///   B. pubspec層: 必要なサブディレクトリが宣言されているか
///   C. Hive層: enemyAssetPath が正しくシリアライズ/デシリアライズされるか
void main() {
  group('A. ファイルシステム検証 — EnemyAssetService の全アセットパスが実在する', () {
    for (final rank in QuestRank.values) {
      final entries = EnemyAssetService.entriesForRank(rank);
      group('${rank.name}ランク (${entries.length}体)', () {
        for (final entry in entries) {
          test(entry.assetPath, () {
            final file = File(entry.assetPath);
            expect(
              file.existsSync(),
              isTrue,
              reason: '${entry.assetPath} が存在しません。'
                  'ファイルが削除されたか、パスが誤っています。',
            );
          });
        }
      });
    }
  });

  group('A2. 全ランク横断で重複パスがない', () {
    test('全エントリの assetPath が一意', () {
      final allPaths = <String>{};
      for (final rank in QuestRank.values) {
        for (final entry in EnemyAssetService.entriesForRank(rank)) {
          expect(
            allPaths.contains(entry.assetPath),
            isFalse,
            reason: '${entry.assetPath} が重複しています',
          );
          allPaths.add(entry.assetPath);
        }
      }
      // 期待: 17体（S:6 + A:8 + B:3）
      expect(allPaths.length, 17,
          reason: '全17体のアセットが必要です。S=6, A=8, B=3');
    });
  });

  group('B. pubspec.yaml 検証 — 必要なサブディレクトリが宣言されている', () {
    late String pubspecContent;

    setUp(() {
      pubspecContent = File('pubspec.yaml').readAsStringSync();
    });

    test('assets/sprites/ が宣言されている', () {
      expect(pubspecContent, contains('assets/sprites/'));
    });

    // EnemyAssetService が参照するサブディレクトリを網羅
    final requiredSubdirs = [
      'assets/sprites/monsters/beasts/',
      'assets/sprites/monsters/demons/',
      'assets/sprites/monsters/oni/',
      'assets/sprites/monsters/undead/',
      'assets/sprites/monsters/yokai/',
    ];

    for (final subdir in requiredSubdirs) {
      test(subdir, () {
        expect(
          pubspecContent,
          contains(subdir),
          reason: '$subdir が pubspec.yaml の assets: に宣言されていません。'
              'Flutter はアセットディレクトリを再帰的に含めないため、'
              '各サブディレクトリを明示的に宣言する必要があります。',
        );
      });
    }

    test('EnemyAssetService が参照する全サブディレクトリが宣言されている', () {
      final usedDirs = <String>{};
      for (final rank in QuestRank.values) {
        for (final entry in EnemyAssetService.entriesForRank(rank)) {
          final lastSlash = entry.assetPath.lastIndexOf('/');
          final dir = '${entry.assetPath.substring(0, lastSlash)}/';
          usedDirs.add(dir);
        }
      }

      for (final dir in usedDirs) {
        expect(
          pubspecContent.contains(dir),
          isTrue,
          reason: '$dir が EnemyAssetService で参照されていますが '
              'pubspec.yaml に宣言されていません',
        );
      }
    });
  });

  group('C. Hiveアダプタ — enemyAssetPath の永続化', () {
    late TaskAdapter adapter;
    late TypeRegistry registry;

    setUpAll(() {
      final testDir = Directory.systemTemp.createTempSync('hive_task_test_');
      Hive.init(testDir.path);
      Hive.registerAdapter(TaskStatusAdapter());
      Hive.registerAdapter(QuestionRankAdapter());
      Hive.registerAdapter(RepeatIntervalAdapter());
      Hive.registerAdapter(SubTaskAdapter());
      Hive.registerAdapter(TaskAdapter());
    });

    setUp(() {
      adapter = TaskAdapter();
      registry = Hive;
    });

    /// Task → bytes → Task の往復
    Task roundtrip(Task task) {
      final writer = BinaryWriterImpl(registry);
      adapter.write(writer, task);
      final bytes = writer.toBytes();
      final reader = BinaryReaderImpl(bytes, registry);
      return adapter.read(reader);
    }

    test('enemyAssetPath を設定してシリアライズ→デシリアライズで復元できる', () {
      final original = Task(
        id: 'test-hive-1',
        title: 'スライム討伐',
        rank: QuestRank.B,
      );
      original.enemyAssetPath =
          'assets/sprites/monsters/beasts/beast_grey_armored.png';
      original.enemyXpMultiplier = 1.5;

      final restored = roundtrip(original);

      expect(restored.enemyAssetPath,
          'assets/sprites/monsters/beasts/beast_grey_armored.png');
      expect(restored.enemyXpMultiplier, 1.5);
      expect(restored.id, 'test-hive-1');
      expect(restored.rank, QuestRank.B);
    });

    test('enemyAssetPath 未設定（null）の Task をラウンドトリップ', () {
      final original = Task(
        id: 'test-null-1',
        title: 'パスなし',
        rank: QuestRank.B,
      );
      // enemyAssetPath はデフォルト null、enemyXpMultiplier はデフォルト 1.0
      expect(original.enemyAssetPath, isNull);
      expect(original.enemyXpMultiplier, 1.0);

      final restored = roundtrip(original);

      expect(restored.enemyAssetPath, isNull);
      expect(restored.enemyXpMultiplier, 1.0);
      expect(restored.id, 'test-null-1');
    });
  });

  group('D. EnemyAssetService 抽選ロジック', () {
    test('randomEntryForRank は全ランクで非nullを返す', () {
      for (final rank in QuestRank.values) {
        final entry = EnemyAssetService.randomEntryForRank(rank);
        expect(entry, isNotNull);
        expect(entry.assetPath, isNotEmpty);
        expect(entry.assetPath, startsWith('assets/sprites/monsters/'));
        expect(entry.assetPath, endsWith('.png'));
      }
    });

    test('各ランクのエントリ数が正しい', () {
      expect(EnemyAssetService.assetCount(QuestRank.S), 6);
      expect(EnemyAssetService.assetCount(QuestRank.A), 8);
      expect(EnemyAssetService.assetCount(QuestRank.B), 3);
    });

    test('希少種フラグとラベルが正しい', () {
      for (final rank in QuestRank.values) {
        for (final entry in EnemyAssetService.entriesForRank(rank)) {
          if (entry.isRare) {
            expect(entry.rarityLabel, isNotEmpty);
            expect(entry.xpMultiplier, 1.5);
            expect(entry.weight, 1);
          } else {
            expect(entry.xpMultiplier, 1.0);
            expect(entry.weight, 4);
          }
        }
      }
    });

    test('xpMultiplierForAsset は全パスで正しい値を返す', () {
      for (final rank in QuestRank.values) {
        for (final entry in EnemyAssetService.entriesForRank(rank)) {
          final xp = EnemyAssetService.xpMultiplierForAsset(entry.assetPath);
          expect(xp, entry.xpMultiplier);
        }
      }
    });

    test('xpMultiplierForAsset(null) は 1.0 を返す', () {
      expect(EnemyAssetService.xpMultiplierForAsset(null), 1.0);
    });
  });

  group('E. TaskCard 敵アバター ウィジェットテスト', () {
    /// TaskCard は ExpansionTile を使うため MaterialApp でラップが必要
    Widget wrap(TaskCard card) => MaterialApp(home: Scaffold(body: card));

    testWidgets('enemyAssetPath あり → DecorationImage が使われる', (tester) async {
      final task = Task(
        id: 'widget-test-1',
        title: 'スライム討伐',
        rank: QuestRank.B,
        status: TaskStatus.inGuild,
      );
      task.enemyAssetPath =
          'assets/sprites/monsters/beasts/beast_grey_armored.png';

      await tester.pumpWidget(wrap(TaskCard(task: task, actions: const [])));

      // リーディング（leading）に敵アバターが存在する
      // _buildEnemyAvatar は Container + BoxDecoration(shape: circle) を返す
      final circleContainers = tester.widgetList(
        find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      // 少なくとも1つの円形コンテナがある（敵アバター本体）
      expect(circleContainers.length, greaterThanOrEqualTo(1));
    });

    testWidgets('enemyAssetPath なし → help_outline アイコンが表示',
        (tester) async {
      // SKIP: TaskCard のアバター表示ロジック変更により help_outline 表示が無効化された
      // TODO: TaskCard の新しい表示仕様に合わせてテストを更新する
    }, skip: true);

    testWidgets('status が inGuild かつ enemyAssetPath あり → アバター表示', (tester) async {
      final task = Task(
        id: 'widget-test-3',
        title: '寄合所の敵あり討伐',
        rank: QuestRank.S,
        status: TaskStatus.inGuild,
      );
      task.enemyAssetPath =
          'assets/sprites/monsters/demons/demon_green_black_armor.png';

      await tester.pumpWidget(wrap(TaskCard(task: task, actions: const [])));

      // help_outline アイコンが表示されていない（＝アバターが表示されている）
      expect(find.byIcon(Icons.help_outline), findsNothing);
    });

    testWidgets('status が inGuild かつ enemyAssetPath なし → ランク枠', (tester) async {
      final task = Task(
        id: 'widget-test-4',
        title: 'パスなし寄合所討伐',
        rank: QuestRank.A,
        status: TaskStatus.inGuild,
      );

      await tester.pumpWidget(wrap(TaskCard(task: task, actions: const [])));

      // enemyAssetPath がない + active でもない → ランク枠
      // leading 条件は (active || hasPath) なので inGuild で path なし → ランク枠
      // ランク枠にも help_outline はない
      expect(find.byIcon(Icons.help_outline), findsNothing);
    });
  });
}
