import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/text/japanese_number.dart';

void main() {
  group('JapaneseNumber.normalizeDigits', () {
    test('全角数字を半角へ変換する', () {
      expect(JapaneseNumber.normalizeDigits('０１２３４５６７８９'), '0123456789');
    });

    test('全角カンマを除去する', () {
      expect(JapaneseNumber.normalizeDigits('１，０００'), '1000');
    });

    test('半角カンマを除去する', () {
      expect(JapaneseNumber.normalizeDigits('1,000'), '1000');
    });

    test('全角と半角が混在しても桁が崩れない', () {
      expect(JapaneseNumber.normalizeDigits('１，２３４'), '1234');
    });

    test('全角マイナス U+FF0D を ASCII ハイフンへ変換する', () {
      expect(JapaneseNumber.normalizeDigits('－５'), '-5');
    });

    test('数学記号マイナス U+2212 を ASCII ハイフンへ変換する', () {
      expect(JapaneseNumber.normalizeDigits('−５'), '-5');
    });

    test('全角空白を半角空白へ変換し、前後を trim する', () {
      expect(JapaneseNumber.normalizeDigits('　３０　'), '30');
    });

    test('数字以外の文字はそのまま残す', () {
      expect(JapaneseNumber.normalizeDigits('１２abc'), '12abc');
    });
  });

  group('JapaneseNumber.tryParseInt', () {
    test('半角数字は従来どおり解釈する', () {
      expect(JapaneseNumber.tryParseInt('30'), 30);
    });

    test('全角数字を解釈する', () {
      expect(JapaneseNumber.tryParseInt('３０'), 30);
    });

    test('全角カンマ区切りを解釈する', () {
      expect(JapaneseNumber.tryParseInt('１，０００'), 1000);
    });

    test('混在した桁区切り １，２３４ を 1234 と解釈する', () {
      expect(JapaneseNumber.tryParseInt('１，２３４'), 1234);
    });

    test('全角マイナスの負値を解釈する', () {
      expect(JapaneseNumber.tryParseInt('－５'), -5);
    });

    test('半角マイナスの負値を解釈する', () {
      expect(JapaneseNumber.tryParseInt('-42'), -42);
    });

    test('全角ゼロは 0 を返す（null ではない）', () {
      expect(JapaneseNumber.tryParseInt('０'), 0);
    });

    test('null は null', () {
      expect(JapaneseNumber.tryParseInt(null), isNull);
    });

    test('空文字は null', () {
      expect(JapaneseNumber.tryParseInt(''), isNull);
    });

    test('全角空白のみは null', () {
      expect(JapaneseNumber.tryParseInt('　　'), isNull);
    });

    test('末尾にゴミがある 123abc は null', () {
      expect(JapaneseNumber.tryParseInt('123abc'), isNull);
    });

    test('単位付きの 30分 は null（黙って 30 にしない）', () {
      expect(JapaneseNumber.tryParseInt('30分'), isNull);
    });
  });

  group('JapaneseNumber.parseIntOr', () {
    test('解釈できる値はその値', () {
      expect(JapaneseNumber.parseIntOr('３０', -1), 30);
    });

    test('解釈できない値はフォールバック', () {
      expect(JapaneseNumber.parseIntOr('abc', 7), 7);
    });

    test('null はフォールバック', () {
      expect(JapaneseNumber.parseIntOr(null, 0), 0);
    });
  });
}
