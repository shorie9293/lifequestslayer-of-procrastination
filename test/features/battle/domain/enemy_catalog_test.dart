import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:rpg_todo/features/battle/domain/enemy_catalog.dart';

/// 敵討伐図鑑ドメイン層の試練。
void main() {
  final base = DateTime(2026, 9, 20, 9, 0);

  BattleRecord record(
    String id,
    String assetPath, {
    bool isVictory = true,
    DateTime? occurredAt,
  }) {
    return BattleRecord(
      id: id,
      title: 'title-$id',
      occurredAt: occurredAt ?? base,
      isVictory: isVictory,
      enemyAssetPath: assetPath,
    );
  }

  EnemyCatalogEntry entry(
    String assetPath, {
    QuestRank rank = QuestRank.A,
    bool isRare = false,
    int defeatCount = 0,
    DateTime? firstDefeatedAt,
    DateTime? lastDefeatedAt,
  }) {
    return EnemyCatalogEntry(
      assetPath: assetPath,
      rank: rank,
      isRare: isRare,
      defeatCount: defeatCount,
      firstDefeatedAt: firstDefeatedAt,
      lastDefeatedAt: lastDefeatedAt,
    );
  }

  group('enemyDisplayNameFromAsset', () {
    test('通常パスをDisplayNameへ変換する', () {
      expect(
        enemyDisplayNameFromAsset(
          'assets/sprites/monsters/demons/demon_green_black_armor.png',
        ),
        'Demon Green Black Armor',
      );
    });

    test('拡張子なしでも変換できる', () {
      expect(
        enemyDisplayNameFromAsset('assets/monsters/ogre_green'),
        'Ogre Green',
      );
    });

    test('空パスは空文字', () {
      expect(enemyDisplayNameFromAsset(''), '');
    });
  });

  group('EnemyCatalogEntry 不変条件', () {
    test('空の assetPath は ArgumentError', () {
      expect(
        () => EnemyCatalogEntry(assetPath: '', rank: QuestRank.S),
        throwsArgumentError,
      );
    });

    test('負の defeatCount は 0 に丸められる', () {
      final e = entry('assets/x/y.png', defeatCount: -3);
      expect(e.defeatCount, 0);
      expect(e.isDiscovered, isFalse);
    });

    test('isDiscovered / displayName / rankLabel', () {
      final e = entry(
        'assets/sprites/monsters/demons/demon_green_black_armor.png',
        rank: QuestRank.S,
        defeatCount: 1,
      );
      expect(e.isDiscovered, isTrue);
      expect(e.displayName, 'Demon Green Black Armor');
      expect(e.rankLabel, 'S');
    });

    test('copyWith は対象フィールドのみ変更する', () {
      final first = DateTime(2026, 9, 1);
      final last = DateTime(2026, 9, 2);
      final e = entry('assets/x/y.png', defeatCount: 1, firstDefeatedAt: first);
      final c = e.copyWith(defeatCount: 5, lastDefeatedAt: last);
      expect(c.defeatCount, 5);
      expect(c.lastDefeatedAt, last);
      expect(c.firstDefeatedAt, first);
      expect(c.assetPath, e.assetPath);
      expect(c.rank, e.rank);
    });
  });

  group('sortByRank', () {
    test('S→A→B、同ランクは rare 先、assetPath 昇順', () {
      final b1 = entry('assets/b1.png', rank: QuestRank.B);
      final aRare = entry('assets/a2.png', rank: QuestRank.A, isRare: true);
      final aNormal = entry('assets/a1.png', rank: QuestRank.A);
      final s = entry('assets/s1.png', rank: QuestRank.S);
      final aRare2 = entry('assets/a0.png', rank: QuestRank.A, isRare: true);

      final sorted = EnemyCatalogService.sortByRank([b1, aRare, aNormal, s, aRare2]);

      expect(
        sorted.map((e) => e.assetPath).toList(),
        ['assets/s1.png', 'assets/a0.png', 'assets/a2.png', 'assets/a1.png', 'assets/b1.png'],
      );
    });

    test('非破壊（入力リストを変更しない）', () {
      final b1 = entry('assets/b1.png', rank: QuestRank.B);
      final s = entry('assets/s1.png', rank: QuestRank.S);
      final input = [b1, s];
      EnemyCatalogService.sortByRank(input);
      expect(input.map((e) => e.assetPath).toList(), ['assets/b1.png', 'assets/s1.png']);
    });
  });

  group('filterUndiscovered / filterRare', () {
    test('filterUndiscovered は非発見のみ・入力順保持・非破壊', () {
      final d1 = entry('assets/1.png', defeatCount: 1);
      final u1 = entry('assets/2.png');
      final d2 = entry('assets/3.png', defeatCount: 2);
      final input = [d1, u1, d2];
      final result = EnemyCatalogService.filterUndiscovered(input);
      expect(result.map((e) => e.assetPath), ['assets/2.png']);
      expect(input.length, 3);
    });

    test('filterRare は rare のみ・入力順保持', () {
      final n = entry('assets/1.png');
      final r1 = entry('assets/2.png', isRare: true);
      final r2 = entry('assets/3.png', isRare: true);
      final result = EnemyCatalogService.filterRare([n, r1, n, r2]);
      expect(result.map((e) => e.assetPath), ['assets/2.png', 'assets/3.png']);
    });
  });

  group('build', () {
    test('勝利のみ集計し敗北は数えない', () {
      final template = [
        entry('assets/win.png'),
        entry('assets/lose.png'),
      ];
      final catalog = EnemyCatalogService.build(
        records: [
          record('r1', 'assets/win.png'),
          record('r2', 'assets/lose.png', isVictory: false),
        ],
        template: template,
      );
      final win = catalog.entries.firstWhere((e) => e.assetPath == 'assets/win.png');
      final lose = catalog.entries.firstWhere((e) => e.assetPath == 'assets/lose.png');
      expect(win.defeatCount, 1);
      expect(lose.defeatCount, 0);
    });

    test('enemyAssetPath が null / 空 / 未知の記録は無視', () {
      final template = [entry('assets/known.png')];
      final catalog = EnemyCatalogService.build(
        records: [
          BattleRecord(
            id: 'r1',
            title: 't1',
            occurredAt: base,
            isVictory: true,
          ),
          record('r2', ''),
          record('r3', 'assets/unknown.png'),
        ],
        template: template,
      );
      expect(catalog.entries.first.defeatCount, 0);
      expect(catalog.discoveredCount, 0);
    });

    test('first/last defeatedAt は最古・最新の occurredAt', () {
      final template = [entry('assets/x.png')];
      final t1 = DateTime(2026, 9, 10);
      final t2 = DateTime(2026, 9, 5);
      final t3 = DateTime(2026, 9, 15);
      final catalog = EnemyCatalogService.build(
        records: [
          record('r1', 'assets/x.png', occurredAt: t1),
          record('r2', 'assets/x.png', occurredAt: t2),
          record('r3', 'assets/x.png', occurredAt: t3),
        ],
        template: template,
      );
      final e = catalog.entries.first;
      expect(e.defeatCount, 3);
      expect(e.firstDefeatedAt, t2);
      expect(e.lastDefeatedAt, t3);
    });

    test('空 records で全滅（complete 0）', () {
      final catalog = EnemyCatalogService.build(
        records: const [],
        template: [
          entry('assets/1.png'),
          entry('assets/2.png'),
        ],
      );
      expect(catalog.totalCount, 2);
      expect(catalog.discoveredCount, 0);
      expect(catalog.completionPercent, 0);
      expect(catalog.isComplete, isFalse);
    });

    test('返り値 entries は sortByRank 済みで不変', () {
      final catalog = EnemyCatalogService.build(
        records: const [],
        template: [
          entry('assets/b.png', rank: QuestRank.B),
          entry('assets/s.png', rank: QuestRank.S),
          entry('assets/a.png', rank: QuestRank.A),
        ],
      );
      expect(
        catalog.entries.map((e) => e.assetPath).toList(),
        ['assets/s.png', 'assets/a.png', 'assets/b.png'],
      );
      expect(() => catalog.entries.add(entry('assets/z.png')), throwsUnsupportedError);
    });
  });

  group('EnemyCatalog 集計getter', () {
    test('completionRatio 0除算回避', () {
      expect(EnemyCatalog(const []).completionRatio, 0.0);
      expect(EnemyCatalog(const []).totalCount, 0);
      expect(EnemyCatalog(const []).isComplete, isFalse);
    });

    test('completionRatio / completionPercent / isComplete', () {
      final catalog = EnemyCatalog([
        entry('assets/1.png', defeatCount: 1),
        entry('assets/2.png'),
        entry('assets/3.png'),
        entry('assets/4.png'),
      ]);
      expect(catalog.totalCount, 4);
      expect(catalog.discoveredCount, 1);
      expect(catalog.completionRatio, closeTo(0.25, 1e-9));
      expect(catalog.completionPercent, 25);
      expect(catalog.completionLabel, '1 / 4 種');
      expect(catalog.isComplete, isFalse);
    });

    test('isComplete は全発見時 true', () {
      final catalog = EnemyCatalog([
        entry('assets/1.png', defeatCount: 1),
        entry('assets/2.png', defeatCount: 2),
      ]);
      expect(catalog.isComplete, isTrue);
      expect(catalog.completionPercent, 100);
    });

    test('undiscovered / rare / totalDefeats / entriesForRank', () {
      final catalog = EnemyCatalog([
        entry('assets/1.png', rank: QuestRank.S, defeatCount: 2),
        entry('assets/2.png', rank: QuestRank.A, isRare: true),
        entry('assets/3.png', rank: QuestRank.A, defeatCount: 1),
        entry('assets/4.png', rank: QuestRank.B),
      ]);
      expect(catalog.undiscovered.map((e) => e.assetPath), ['assets/2.png', 'assets/4.png']);
      expect(catalog.rare.map((e) => e.assetPath), ['assets/2.png']);
      expect(catalog.totalDefeats, 3);
      expect(catalog.entriesForRank(QuestRank.A).length, 2);
      expect(catalog.entriesForRank(QuestRank.S).length, 1);
    });

    test('entries は不変', () {
      final catalog = EnemyCatalog([entry('assets/1.png')]);
      expect(() => catalog.entries.add(entry('assets/2.png')), throwsUnsupportedError);
    });
  });

  group('allEntries', () {
    test('全ランク17体・rank/isRare/rarityLabel を引き継ぐ', () {
      final all = EnemyCatalogService.allEntries();
      expect(all.length, EnemyAssetService.assetCount(QuestRank.S) +
          EnemyAssetService.assetCount(QuestRank.A) +
          EnemyAssetService.assetCount(QuestRank.B));

      final rareCount = all.where((e) => e.isRare).length;
      expect(rareCount, 5);

      final demon = all.firstWhere(
        (e) => e.assetPath == 'assets/sprites/monsters/demons/demon_green_black_armor.png',
      );
      expect(demon.rank, QuestRank.S);
      expect(demon.rarityLabel, '');

      final awake = all.firstWhere(
        (e) => e.assetPath == 'assets/sprites/monsters/demons/demon_red_black_winged.png',
      );
      expect(awake.rank, QuestRank.S);
      expect(awake.isRare, isTrue);
      expect(awake.rarityLabel, '覚醒体');
    });
  });

  group('BattleRecord enemyAssetPath 後方互換', () {
    test('キー欠落 JSON から読める', () {
      final json = {
        'id': 'r1',
        'title': 't',
        'occurredAt': base.toIso8601String(),
        'isVictory': true,
        'comboCount': 0,
        'remainingSubTasks': 0,
      };
      final r = BattleRecord.fromJson(json);
      expect(r.enemyAssetPath, isNull);
    });

    test('往復で enemyAssetPath を保持する', () {
      final r = record('r1', 'assets/x.png');
      final restored = BattleRecord.fromJson(r.toJson());
      expect(restored.enemyAssetPath, 'assets/x.png');
      expect(restored, r);
    });

    test('空文字 enemyAssetPath は null になる', () {
      final json = {
        'id': 'r1',
        'title': 't',
        'occurredAt': base.toIso8601String(),
        'isVictory': true,
        'comboCount': 0,
        'remainingSubTasks': 0,
        'enemyAssetPath': '',
      };
      expect(BattleRecord.fromJson(json).enemyAssetPath, isNull);
    });

    test('非String enemyAssetPath は null になる', () {
      final json = {
        'id': 'r1',
        'title': 't',
        'occurredAt': base.toIso8601String(),
        'isVictory': true,
        'comboCount': 0,
        'remainingSubTasks': 0,
        'enemyAssetPath': 42,
      };
      expect(BattleRecord.fromJson(json).enemyAssetPath, isNull);
    });

    test('必須フィールド欠落は FormatException のまま', () {
      expect(
        () => BattleRecord.fromJson({'id': 'r1'}),
        throwsFormatException,
      );
    });
  });
}
