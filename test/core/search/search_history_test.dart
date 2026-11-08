// 検索語履歴（純粋 Dart）の試練。
//
// add の正規化・重複排除・上限、encode/decode の頑健さを検証する。

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/search/search_history.dart';

void main() {
  test('add は新しい語を先頭へ積む', () {
    final history = const SearchHistory.empty().add('討伐').add('採集').add('学問');

    expect(history.entries, ['学問', '採集', '討伐']);
  });

  test('大文字小文字を無視した重複は先頭へ移動し、表記は新しい入力で置換される', () {
    final history =
        const SearchHistory.empty().add('Dragon').add('goblin').add('DRAGON');

    expect(history.entries, ['DRAGON', 'goblin']);
    expect(history.entries, hasLength(2));
  });

  test('上限8件を超えたら最古を落とす', () {
    var history = const SearchHistory.empty();
    for (var i = 1; i <= 10; i++) {
      history = history.add('語$i');
    }

    expect(history.entries, hasLength(SearchHistory.maxEntries));
    expect(history.entries.first, '語10');
    expect(history.entries.last, '語3');
    expect(history.entries, isNot(contains('語1')));
    expect(history.entries, isNot(contains('語2')));
  });

  test('空文字・空白のみは積まず、自分自身を返す', () {
    final history = const SearchHistory.empty().add('討伐');

    expect(identical(history.add(''), history), isTrue);
    expect(identical(history.add('   '), history), isTrue);
    expect(identical(history.add('\u3000\u3000'), history), isTrue);
    expect(history.entries, ['討伐']);
  });

  test('全角空白は半角へ、連続空白は1つに畳み、前後を trim する', () {
    final history = const SearchHistory.empty().add('  ドラゴン\u3000\u3000討伐  ');

    expect(history.entries.single, 'ドラゴン 討伐');
  });

  test('前後の空白だけが違う語は同一とみなして重複しない', () {
    final history = const SearchHistory.empty().add('  採集  ').add('採集\u3000');

    expect(history.entries, ['採集']);
  });

  test('encode → decode で順序どおり往復する', () {
    final history =
        const SearchHistory.empty().add('討伐').add('札: 戦闘').add('ドラゴン 討伐');

    final restored = SearchHistory.decode(history.encode());

    expect(restored, history);
    expect(restored.entries, ['ドラゴン 討伐', '札: 戦闘', '討伐']);
  });

  test('decode は壊れた JSON でも例外を投げず空へ落ちる', () {
    expect(SearchHistory.decode(null).entries, isEmpty);
    expect(SearchHistory.decode('').entries, isEmpty);
    expect(SearchHistory.decode('   ').entries, isEmpty);
    expect(SearchHistory.decode('{not json').entries, isEmpty);
    expect(SearchHistory.decode('{"entries": [1, 2').entries, isEmpty);
  });

  test('decode は型不一致・非文字列要素を捨てる', () {
    expect(SearchHistory.decode('[]').entries, isEmpty);
    expect(SearchHistory.decode('"文字列"').entries, isEmpty);
    expect(SearchHistory.decode('{"entries": 3}').entries, isEmpty);
    expect(SearchHistory.decode('{"other": ["a"]}').entries, isEmpty);

    final mixed =
        SearchHistory.decode('{"entries": ["討伐", 1, null, "", "  ", "採集"]}');
    expect(mixed.entries, ['討伐', '採集']);
  });

  test('decode は9件以上を8件へ切り詰める', () {
    const raw = '{"entries": ["1","2","3","4","5","6","7","8","9"]}';

    final decoded = SearchHistory.decode(raw);

    expect(decoded.entries, hasLength(8));
    expect(decoded.entries.last, '8');
  });

  test('const 空コンストラクタは空である', () {
    const history = SearchHistory.empty();

    expect(history.isEmpty, isTrue);
    expect(history.entries, isEmpty);
  });
}
