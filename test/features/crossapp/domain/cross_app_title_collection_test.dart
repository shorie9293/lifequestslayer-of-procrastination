import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_collection.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';

/// 12件定義から期待される称号ID（定義順）
const _allTitleIds = <String>[
  '読書家の卵',
  '書庫の冒険者',
  '知の探究者',
  '千巻の賢者',
  '読書の継続者',
  '日々の読書人',
  '不滅の読書家',
  '知識の探求者',
  '知の航海者',
  'ページを征く者',
  '万頁の読破者',
];

void main() {
  const service = CrossAppTitleService();

  group('CrossAppTitleFilter', () {
    test('all のラベルは「すべて」', () {
      expect(CrossAppTitleFilter.all.label, 'すべて');
    });

    test('earned のラベルは「獲得済み」', () {
      expect(CrossAppTitleFilter.earned.label, '獲得済み');
    });

    test('unearned のラベルは「未獲得」', () {
      expect(CrossAppTitleFilter.unearned.label, '未獲得');
    });
  });

  group('kCrossAppEventTypeLabels', () {
    test('4つのイベント種別ラベルを持つ', () {
      expect(kCrossAppEventTypeLabels['book_completed'], '読了冊数');
      expect(kCrossAppEventTypeLabels['reading_streak'], '連続読書日数');
      expect(kCrossAppEventTypeLabels['xp_milestone'], '獲得XP');
      expect(kCrossAppEventTypeLabels['pages_milestone'], '読了ページ数');
      expect(kCrossAppEventTypeLabels.length, 4);
    });
  });

  group('CrossAppTitleService.build', () {
    test('ownedTitles が空でも全11件が定義順で並ぶ', () {
      final collection = service.build(ownedTitles: const []);

      expect(collection.total, 11);
      expect(collection.total, kCrossAppTitles.length);
      expect(
        collection.entries.map((e) => e.id).toList(),
        _allTitleIds,
      );
    });

    test('全未獲得なら earnedCount は 0、achievementRatio は 0.0', () {
      final collection = service.build(ownedTitles: const []);

      expect(collection.earnedCount, 0);
      expect(collection.unearnedCount, 11);
      expect(collection.achievementRatio, 0.0);
      expect(collection.earned, isEmpty);
    });

    test('全獲得なら earnedCount 11、achievementRatio 1.0', () {
      final collection = service.build(ownedTitles: _allTitleIds);

      expect(collection.earnedCount, 11);
      expect(collection.unearnedCount, 0);
      expect(collection.achievementRatio, 1.0);
      expect(collection.unearned, isEmpty);
    });

    test('未知の称号名は無視される', () {
      final collection = service.build(
        ownedTitles: const ['読書家の卵', '存在しない称号', '謎の称号'],
      );

      expect(collection.earnedCount, 1);
      expect(collection.total, 11);
      expect(collection.entryFor('存在しない称号'), isNull);
    });

    test('ownedTitles の重複は単一扱い', () {
      final collection = service.build(
        ownedTitles: const ['読書家の卵', '読書家の卵', '読書家の卵'],
      );

      expect(collection.earnedCount, 1);
      expect(collection.total, 11);
    });

    test('獲得済みの称号だけ isEarned が true になる', () {
      final collection = service.build(ownedTitles: const ['書庫の冒険者']);

      for (final entry in collection.entries) {
        expect(entry.isEarned, entry.id == '書庫の冒険者', reason: entry.id);
      }
    });

    test('完全一致のみで獲得判定する（部分一致は不可）', () {
      final collection = service.build(ownedTitles: const ['読書家']);

      expect(collection.earnedCount, 0);
    });

    test('definitions の独自順序をそのまま保持する', () {
      const definitions = <CrossAppTitleDefinition>[
        CrossAppTitleDefinition(
          id: 'ページを征く者',
          eventType: 'pages_milestone',
          threshold: 1000,
        ),
        CrossAppTitleDefinition(
          id: '読書家の卵',
          eventType: 'book_completed',
          threshold: 1,
        ),
      ];

      final collection = service.build(
        ownedTitles: const [],
        definitions: definitions,
      );

      expect(collection.total, 2);
      expect(
        collection.entries.map((e) => e.id).toList(),
        ['ページを征く者', '読書家の卵'],
      );
    });

    test('definitions が空なら total 0・achievementRatio 0.0（0除算なし）', () {
      final collection = service.build(
        ownedTitles: const ['読書家の卵'],
        definitions: const [],
      );

      expect(collection.total, 0);
      expect(collection.earnedCount, 0);
      expect(collection.unearnedCount, 0);
      expect(collection.achievementRatio, 0.0);
      expect(collection.ratioLabel, '0%');
      expect(collection.groups, isEmpty);
    });

    test('build は同一入力に対して同じ結果を返す（純粋）', () {
      final a = service.build(ownedTitles: const ['読書家の卵']);
      final b = service.build(ownedTitles: const ['読書家の卵']);

      expect(
        a.entries.map((e) => '${e.id}:${e.isEarned}').toList(),
        b.entries.map((e) => '${e.id}:${e.isEarned}').toList(),
      );
    });
  });

  group('CrossAppTitleEntry', () {
    test('id は definition.id を返す', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles.first,
        isEarned: false,
      );

      expect(entry.id, '読書家の卵');
      expect(entry.id, entry.definition.id);
    });

    test('conditionLabel: 読了 1冊', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[0],
        isEarned: false,
      );

      expect(entry.conditionLabel, '読了 1冊');
    });

    test('conditionLabel: 読了 50冊', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[3],
        isEarned: false,
      );

      expect(entry.conditionLabel, '読了 50冊');
    });

    test('conditionLabel: 連続 7日', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[4],
        isEarned: false,
      );

      expect(entry.conditionLabel, '連続 7日');
    });

    test('conditionLabel: 連続 100日', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[6],
        isEarned: false,
      );

      expect(entry.conditionLabel, '連続 100日');
    });

    test('conditionLabel: XP 1,000（3桁区切り）', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[7],
        isEarned: false,
      );

      expect(entry.conditionLabel, 'XP 1,000');
    });

    test('conditionLabel: XP 10,000（3桁区切り）', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[8],
        isEarned: false,
      );

      expect(entry.conditionLabel, 'XP 10,000');
    });

    test('conditionLabel: 通算 1,000ページ', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[9],
        isEarned: false,
      );

      expect(entry.conditionLabel, '通算 1,000ページ');
    });

    test('conditionLabel: 通算 10,000ページ', () {
      final entry = CrossAppTitleEntry(
        definition: kCrossAppTitles[10],
        isEarned: false,
      );

      expect(entry.conditionLabel, '通算 10,000ページ');
    });

    test('conditionLabel: 4種すべてが単位付きで組み立てられる', () {
      final labels = <String, String>{};
      for (final entry in service.build(ownedTitles: const []).entries) {
        labels[entry.definition.eventType] ??= entry.conditionLabel;
      }

      expect(labels['book_completed'], '読了 1冊');
      expect(labels['reading_streak'], '連続 7日');
      expect(labels['xp_milestone'], 'XP 1,000');
      expect(labels['pages_milestone'], '通算 1,000ページ');
      expect(labels.length, 4);
    });

    test('eventTypeLabel: 4種のイベント種別を日本語化する', () {
      final labels = <String, String>{};
      for (final entry in service.build(ownedTitles: const []).entries) {
        labels[entry.definition.eventType] ??= entry.eventTypeLabel;
      }

      expect(labels['book_completed'], '読了冊数');
      expect(labels['reading_streak'], '連続読書日数');
      expect(labels['xp_milestone'], '獲得XP');
      expect(labels['pages_milestone'], '読了ページ数');
    });

    test('eventTypeLabel: 未知のイベント種別は eventType をそのまま返す', () {
      const definition = CrossAppTitleDefinition(
        id: '謎称号',
        eventType: 'unknown_event',
        threshold: 3,
      );
      const entry = CrossAppTitleEntry(definition: definition, isEarned: false);

      expect(entry.eventTypeLabel, 'unknown_event');
    });

    test('statusLabel: 獲得済み / 未獲得', () {
      final earned = CrossAppTitleEntry(
        definition: kCrossAppTitles.first,
        isEarned: true,
      );
      final unearned = CrossAppTitleEntry(
        definition: kCrossAppTitles.first,
        isEarned: false,
      );

      expect(earned.statusLabel, '獲得済み');
      expect(unearned.statusLabel, '未獲得');
    });
  });

  group('CrossAppTitleCollection 集計', () {
    test('total / earnedCount / unearnedCount が整合する', () {
      final collection = service.build(
        ownedTitles: const ['読書家の卵', '書庫の冒険者', '知の探究者'],
      );

      expect(collection.total, 11);
      expect(collection.earnedCount, 3);
      expect(collection.unearnedCount, 8);
      expect(collection.earnedCount + collection.unearnedCount, collection.total);
    });

    test('summaryLabel: 獲得 3 / 11', () {
      final collection = service.build(
        ownedTitles: const ['読書家の卵', '書庫の冒険者', '知の探究者'],
      );

      expect(collection.summaryLabel, '獲得 3 / 11');
    });

    test('summaryLabel: 全未獲得は 獲得 0 / 11', () {
      expect(
        service.build(ownedTitles: const []).summaryLabel,
        '獲得 0 / 11',
      );
    });

    test('ratioLabel: 1/4 は 25%', () {
      const definitions = <CrossAppTitleDefinition>[
        CrossAppTitleDefinition(
          id: 'A',
          eventType: 'book_completed',
          threshold: 1,
        ),
        CrossAppTitleDefinition(
          id: 'B',
          eventType: 'book_completed',
          threshold: 5,
        ),
        CrossAppTitleDefinition(
          id: 'C',
          eventType: 'xp_milestone',
          threshold: 1000,
        ),
        CrossAppTitleDefinition(
          id: 'D',
          eventType: 'pages_milestone',
          threshold: 1000,
        ),
      ];
      final collection = service.build(
        ownedTitles: const ['A'],
        definitions: definitions,
      );

      expect(collection.summaryLabel, '獲得 1 / 4');
      expect(collection.ratioLabel, '25%');
    });

    test('ratioLabel: 0件は 0%', () {
      expect(service.build(ownedTitles: const []).ratioLabel, '0%');
    });

    test('ratioLabel: 全獲得は 100%', () {
      expect(service.build(ownedTitles: _allTitleIds).ratioLabel, '100%');
    });

    test('achievementRatio: 端数 1/3 は 0.333...（クランプ内）', () {
      const definitions = <CrossAppTitleDefinition>[
        CrossAppTitleDefinition(
          id: 'A',
          eventType: 'book_completed',
          threshold: 1,
        ),
        CrossAppTitleDefinition(
          id: 'B',
          eventType: 'book_completed',
          threshold: 5,
        ),
        CrossAppTitleDefinition(
          id: 'C',
          eventType: 'book_completed',
          threshold: 10,
        ),
      ];
      final collection = service.build(
        ownedTitles: const ['A'],
        definitions: definitions,
      );

      expect(collection.achievementRatio, closeTo(1 / 3, 1e-9));
      expect(collection.achievementRatio, inInclusiveRange(0.0, 1.0));
      expect(collection.ratioLabel, '33%');
    });
  });

  group('CrossAppTitleCollection 一覧', () {
    test('earned は獲得済みのみを定義順で返す', () {
      final collection = service.build(
        ownedTitles: const ['知の探究者', '読書家の卵'],
      );

      expect(
        collection.earned.map((e) => e.id).toList(),
        ['読書家の卵', '知の探究者'],
      );
    });

    test('unearned は未獲得のみを定義順で返す', () {
      final collection = service.build(ownedTitles: const ['読書家の卵']);

      expect(collection.unearned.length, 10);
      expect(collection.unearned.first.id, '書庫の冒険者');
      expect(collection.unearned.last.id, '万頁の読破者');
    });

    test('entryFor は一致する entry を返す', () {
      final collection = service.build(ownedTitles: const ['書庫の冒険者']);
      final entry = collection.entryFor('書庫の冒険者');

      expect(entry, isNotNull);
      expect(entry!.id, '書庫の冒険者');
      expect(entry.isEarned, isTrue);
      expect(entry.definition.threshold, 5);
    });

    test('entryFor は不一致なら null を返す', () {
      final collection = service.build(ownedTitles: const []);

      expect(collection.entryFor('存在しない称号'), isNull);
    });

    test('groups は4イベント種別を初出順で返す', () {
      final collection = service.build(ownedTitles: const []);
      final groups = collection.groups;

      expect(groups.length, 4);
      expect(
        groups.map((g) => g.eventType).toList(),
        ['book_completed', 'reading_streak', 'xp_milestone', 'pages_milestone'],
      );
    });

    test('groups の label はイベント種別ラベルになる', () {
      final groups = service.build(ownedTitles: const []).groups;

      expect(
        groups.map((g) => g.label).toList(),
        ['読了冊数', '連続読書日数', '獲得XP', '読了ページ数'],
      );
    });

    test('groups は各群内で定義順・件数も定義通り', () {
      final groups = service.build(ownedTitles: const []).groups;

      expect(groups[0].entries.map((e) => e.id).toList(), [
        '読書家の卵',
        '書庫の冒険者',
        '知の探究者',
        '千巻の賢者',
      ]);
      expect(groups[1].entries.map((e) => e.id).toList(), [
        '読書の継続者',
        '日々の読書人',
        '不滅の読書家',
      ]);
      expect(groups[2].entries.map((e) => e.id).toList(), [
        '知識の探求者',
        '知の航海者',
      ]);
      expect(groups[3].entries.map((e) => e.id).toList(), [
        'ページを征く者',
        '万頁の読破者',
      ]);
    });

    test('groups は空のイベント種別グループを含めない', () {
      const definitions = <CrossAppTitleDefinition>[
        CrossAppTitleDefinition(
          id: '読書家の卵',
          eventType: 'book_completed',
          threshold: 1,
        ),
        CrossAppTitleDefinition(
          id: '知の航海者',
          eventType: 'xp_milestone',
          threshold: 10000,
        ),
      ];
      final groups = service.build(
        ownedTitles: const [],
        definitions: definitions,
      ).groups;

      expect(groups.length, 2);
      expect(
        groups.map((g) => g.eventType).toList(),
        ['book_completed', 'xp_milestone'],
      );
      expect(groups.every((g) => g.entries.isNotEmpty), isTrue);
    });

    test('groups は未知のイベント種別でも eventType を label にフォールバックする', () {
      const definitions = <CrossAppTitleDefinition>[
        CrossAppTitleDefinition(
          id: '謎称号',
          eventType: 'unknown_event',
          threshold: 3,
        ),
      ];
      final groups = service.build(
        ownedTitles: const [],
        definitions: definitions,
      ).groups;

      expect(groups.single.eventType, 'unknown_event');
      expect(groups.single.label, 'unknown_event');
    });
  });

  group('CrossAppTitleCollection filter', () {
    test('all は全件を返し total 不変', () {
      final collection = service.build(ownedTitles: const ['読書家の卵']);
      final filtered = collection.filter(CrossAppTitleFilter.all);

      expect(filtered.total, collection.total);
      expect(filtered.entries.length, 11);
      expect(filtered.earnedCount, 1);
    });

    test('earned は獲得済みのみ・total は獲得数', () {
      final collection = service.build(
        ownedTitles: const ['読書家の卵', '知の探究者'],
      );
      final filtered = collection.filter(CrossAppTitleFilter.earned);

      expect(filtered.total, 2);
      expect(filtered.earnedCount, 2);
      expect(filtered.unearnedCount, 0);
      expect(
        filtered.entries.map((e) => e.id).toList(),
        ['読書家の卵', '知の探究者'],
      );
      expect(collection.total, 11); // 元は不変
    });

    test('unearned は未獲得のみ・total は未獲得数', () {
      final collection = service.build(ownedTitles: const ['読書家の卵']);
      final filtered = collection.filter(CrossAppTitleFilter.unearned);

      expect(filtered.total, 10);
      expect(filtered.earnedCount, 0);
      expect(filtered.unearnedCount, 10);
      expect(filtered.entries.any((e) => e.id == '読書家の卵'), isFalse);
    });

    test('filter は元コレクションの定義順を保つ', () {
      final collection = service.build(
        ownedTitles: const ['万頁の読破者', '読書家の卵', '不滅の読書家'],
      );
      final filtered = collection.filter(CrossAppTitleFilter.earned);

      expect(
        filtered.entries.map((e) => e.id).toList(),
        ['読書家の卵', '不滅の読書家', '万頁の読破者'],
      );
    });
  });

  group('CrossAppTitleCollection sortedByEarnedFirst', () {
    test('獲得済みが先頭に来る', () {
      final collection = service.build(
        ownedTitles: const ['万頁の読破者', '読書家の卵'],
      );
      final sorted = collection.sortedByEarnedFirst;

      expect(sorted.take(2).every((e) => e.isEarned), isTrue);
      expect(sorted.length, 11);
    });

    test('各群内は定義順を保つ', () {
      final collection = service.build(
        ownedTitles: const ['千巻の賢者', 'ページを征く者', '読書家の卵'],
      );
      final sorted = collection.sortedByEarnedFirst;

      expect(
        sorted.take(3).map((e) => e.id).toList(),
        ['読書家の卵', '千巻の賢者', 'ページを征く者'],
      );
    });

    test('元の entries リストを破壊しない', () {
      final collection = service.build(
        ownedTitles: const ['万頁の読破者'],
      );
      final before = collection.entries.map((e) => e.id).toList();

      collection.sortedByEarnedFirst;

      expect(collection.entries.map((e) => e.id).toList(), before);
      expect(collection.entries.first.isEarned, isFalse);
    });

    test('獲得0件でも順序は定義順のまま', () {
      final collection = service.build(ownedTitles: const []);
      final sorted = collection.sortedByEarnedFirst;

      expect(sorted.map((e) => e.id).toList(), _allTitleIds);
    });
  });
}
