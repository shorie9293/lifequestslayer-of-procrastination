import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/text/kana_fold.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query_service.dart';

Task _task(String id, {String title = 'q', List<String> tags = const []}) =>
    Task(id: id, title: title, tags: List<String>.of(tags));

void main() {
  group('foldKana: ひらがな → カタカナ', () {
    test('基本のかなをカタカナへ +0x60 する', () {
      expect(foldKana('あいうえお'), 'アイウエオ');
      expect(foldKana('かきくけこ'), 'カキクケコ');
      expect(foldKana('まにふぇすと'), 'マニフェスト');
    });

    test('小書き・濁音・半濁音・長音も変換する', () {
      expect(foldKana('ぁぃぅぇぉっゃゅょ'), 'ァィゥェォッャュョ');
      expect(foldKana('がぎぐげござじずぜぞ'), 'ガギグゲゴザジズゼゾ');
      expect(foldKana('ぱぴぷぺぽ'), 'パピプペポ');
      expect(foldKana('ゔ'), 'ヴ');
      expect(foldKana('らーめん'), 'ラーメン');
    });

    test('ゕ(U+3095)・ゖ(U+3096) は ヵ・ヶ になる', () {
      expect(foldKana('ゕゖ'), 'ヵヶ');
      expect(foldKana('一ヶ月'), '一ヶ月');
      expect(foldKana('ゕ').codeUnitAt(0), 0x30F5);
      expect(foldKana('ゖ').codeUnitAt(0), 0x30F6);
    });
  });

  group('foldKana: 半角カナ → 全角カタカナ', () {
    test('ﾏﾆﾌｪｽﾄ は マニフェスト になる', () {
      expect(foldKana('ﾏﾆﾌｪｽﾄ'), 'マニフェスト');
    });

    test('濁点 ﾞ は結合して濁音 1 文字にする', () {
      expect(foldKana('ｶﾞｷﾞｸﾞｹﾞｺﾞ'), 'ガギグゲゴ');
      expect(foldKana('ｻﾞｼﾞｽﾞｾﾞｿﾞ'), 'ザジズゼゾ');
      expect(foldKana('ﾀﾞﾁﾞﾂﾞﾃﾞﾄﾞ'), 'ダヂヅデド');
      expect(foldKana('ﾊﾞﾋﾞﾌﾞﾍﾞﾎﾞ'), 'バビブベボ');
      expect(foldKana('ｳﾞ'), 'ヴ');
    });

    test('半濁点 ﾟ は結合して半濁音 1 文字にする', () {
      expect(foldKana('ﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ'), 'パピプペポ');
      expect(foldKana('ﾊﾟ').codeUnitAt(0), 0x30D1);
    });

    test('小書き・長音・拗音の半角カナ', () {
      expect(foldKana('ｱｲｳｴｵ'), 'アイウエオ');
      expect(foldKana('ｷｬｯﾄ'), 'キャット');
      expect(foldKana('ｺｰﾋｰ'), 'コーヒー');
      expect(foldKana('ｦﾝ'), 'ヲン');
    });

    test('結合先の無い単独の濁点・半濁点は間隔用の ゛/゜ へ', () {
      expect(foldKana('ﾞ'), '\u309B');
      expect(foldKana('ﾟ'), '\u309C');
    });
  });

  group('foldKana: 不変', () {
    test('全角カタカナは不変', () {
      expect(foldKana('マニフェスト'), 'マニフェスト');
      expect(foldKana('ヴヷヺヵヶヮヰヱ'), 'ヴヷヺヵヶヮヰヱ');
    });

    test('ASCII・数字・記号は不変', () {
      expect(foldKana('Slime Lv.10 (boss)!'), 'Slime Lv.10 (boss)!');
      expect(foldKana('abcXYZ0123_-#@'), 'abcXYZ0123_-#@');
    });

    test('漢字・全角英数・全角スペースは不変', () {
      expect(foldKana('掃除 洗濯 ＡＢＣ１２３　家事'), '掃除 洗濯 ＡＢＣ１２３　家事');
    });

    test('空文字は空文字', () {
      expect(foldKana(''), '');
    });
  });

  group('foldKana: 冪等性', () {
    test('2 回適用しても結果が変わらない', () {
      const samples = <String>[
        'まにふぇすと',
        'ﾏﾆﾌｪｽﾄ',
        'ｶﾞｯｺｳ に いく',
        'ゕゖ ゔ ぱぴぷぺぽ',
        'Slime 掃除 ＡＢＣ１２３',
        'ﾞﾟ',
        '',
      ];
      for (final s in samples) {
        final once = foldKana(s);
        expect(foldKana(once), once, reason: 'idempotency failed for "$s"');
      }
    });
  });

  group('GuildQuestQueryService.normalizeForSearch', () {
    test('既存 normalize の戻り値は変わらない（かなは変換しない）', () {
      expect(GuildQuestQueryService.normalize('まにふぇすと'), 'まにふぇすと');
      expect(GuildQuestQueryService.normalize('  ＡＢＣ１２３　'), 'abc123');
      expect(GuildQuestQueryService.normalize('仕事　家事'), '仕事 家事');
    });

    test('全角英数→半角・小文字化のうえでかなを畳む', () {
      expect(
        GuildQuestQueryService.normalizeForSearch('  ﾏﾆﾌｪｽﾄ　ＡＢＣ  '),
        'マニフェスト abc',
      );
      expect(
        GuildQuestQueryService.normalizeForSearch('まにふぇすと'),
        'マニフェスト',
      );
    });
  });

  group('検索統合: matchesText のかな表記ゆれ吸収', () {
    final katakana = _task('1', title: '準備', tags: const ['マニフェスト']);

    test('ひらがな検索語でカタカナ札のタスクがヒットする', () {
      expect(GuildQuestQueryService.matchesText(katakana, 'まにふぇすと'), isTrue);
      expect(GuildQuestQueryService.matchesText(katakana, 'ふぇすと'), isTrue);
    });

    test('半角カナ検索語でカタカナ札のタスクがヒットする', () {
      expect(GuildQuestQueryService.matchesText(katakana, 'ﾏﾆﾌｪｽﾄ'), isTrue);
    });

    test('カタカナ検索語は従来どおりヒットする', () {
      expect(GuildQuestQueryService.matchesText(katakana, 'マニフェスト'), isTrue);
    });

    test('ひらがな title も全角カタカナ検索語でヒットする', () {
      final t = _task('2', title: 'まにふぇすとを書く');
      expect(
        GuildQuestQueryService.matchesText(t, 'マニフェスト'),
        isTrue,
      );
    });

    test('既存のローマ字・全角英数検索は壊れない', () {
      final t = _task('3', title: 'Slime Dungeon', tags: const ['room', '家事']);
      expect(GuildQuestQueryService.matchesText(t, 'slime'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'ＤＵＮＧＥＯＮ'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'geo'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'room'), isTrue);
      expect(GuildQuestQueryService.matchesText(t, 'room2'), isFalse);
      expect(GuildQuestQueryService.matchesText(t, '家事'), isTrue);
    });

    test('無関係な検索語はヒットしない', () {
      expect(GuildQuestQueryService.matchesText(katakana, 'ﾄﾞﾗｺﾞﾝ'), isFalse);
      expect(GuildQuestQueryService.matchesText(katakana, 'どらごん'), isFalse);
    });

    test('空・空白のみの検索語は常に true', () {
      expect(GuildQuestQueryService.matchesText(katakana, ''), isTrue);
      expect(GuildQuestQueryService.matchesText(katakana, '　 '), isTrue);
    });
  });
}
