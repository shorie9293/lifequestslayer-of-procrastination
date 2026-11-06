/// かな表記ゆれの吸収（純粋関数）。
///
/// 検索語と対象文字列の双方に同じ変換をかけることで、
///   * ひらがな「まにふぇすと」 ⇄ カタカナ「マニフェスト」
///   * 半角カナ「ﾏﾆﾌｪｽﾄ」 → 全角カタカナ「マニフェスト」
/// を同一視する。ASCII・漢字・全角カタカナ（既に変換済み）は不変。
///
/// 冪等性: `foldKana(foldKana(x)) == foldKana(x)`。
/// 出力は「ひらがな範囲 U+3041..U+3096」と「半角カナ範囲 U+FF66..U+FF9F」を
/// 含まないため、2 回目以降の適用では何も変化しない。
library;

/// ゛（半角濁点）
const int _dakuten = 0xFF9E;

/// ゜（半角半濁点）
const int _handakuten = 0xFF9F;

/// 半角カナ（U+FF66..U+FF9D）→ 全角カタカナ。表引き必須。
const Map<int, String> _halfwidthToFullwidth = <int, String>{
  0xFF66: 'ヲ', // ｦ
  0xFF67: 'ァ', // ｧ
  0xFF68: 'ィ', // ｨ
  0xFF69: 'ゥ', // ｩ
  0xFF6A: 'ェ', // ｪ
  0xFF6B: 'ォ', // ｫ
  0xFF6C: 'ャ', // ｬ
  0xFF6D: 'ュ', // ｭ
  0xFF6E: 'ョ', // ｮ
  0xFF6F: 'ッ', // ｯ
  0xFF70: 'ー', // ｰ
  0xFF71: 'ア', // ｱ
  0xFF72: 'イ', // ｲ
  0xFF73: 'ウ', // ｳ
  0xFF74: 'エ', // ｴ
  0xFF75: 'オ', // ｵ
  0xFF76: 'カ', // ｶ
  0xFF77: 'キ', // ｷ
  0xFF78: 'ク', // ｸ
  0xFF79: 'ケ', // ｹ
  0xFF7A: 'コ', // ｺ
  0xFF7B: 'サ', // ｻ
  0xFF7C: 'シ', // ｼ
  0xFF7D: 'ス', // ｽ
  0xFF7E: 'セ', // ｾ
  0xFF7F: 'ソ', // ｿ
  0xFF80: 'タ', // ﾀ
  0xFF81: 'チ', // ﾁ
  0xFF82: 'ツ', // ﾂ
  0xFF83: 'テ', // ﾃ
  0xFF84: 'ト', // ﾄ
  0xFF85: 'ナ', // ﾅ
  0xFF86: 'ニ', // ﾆ
  0xFF87: 'ヌ', // ﾇ
  0xFF88: 'ネ', // ﾈ
  0xFF89: 'ノ', // ﾉ
  0xFF8A: 'ハ', // ﾊ
  0xFF8B: 'ヒ', // ﾋ
  0xFF8C: 'フ', // ﾌ
  0xFF8D: 'ヘ', // ﾍ
  0xFF8E: 'ホ', // ﾎ
  0xFF8F: 'マ', // ﾏ
  0xFF90: 'ミ', // ﾐ
  0xFF91: 'ム', // ﾑ
  0xFF92: 'メ', // ﾒ
  0xFF93: 'モ', // ﾓ
  0xFF94: 'ヤ', // ﾔ
  0xFF95: 'ユ', // ﾕ
  0xFF96: 'ヨ', // ﾖ
  0xFF97: 'ラ', // ﾗ
  0xFF98: 'リ', // ﾘ
  0xFF99: 'ル', // ﾙ
  0xFF9A: 'レ', // ﾚ
  0xFF9B: 'ロ', // ﾛ
  0xFF9C: 'ワ', // ﾜ
  0xFF9D: 'ン', // ﾝ
};

/// 「全角カタカナ + 半角濁点(ﾞ)」→ 合成済み濁音 1 文字。
const Map<String, String> _dakutenCombinations = <String, String>{
  'カ': 'ガ',
  'キ': 'ギ',
  'ク': 'グ',
  'ケ': 'ゲ',
  'コ': 'ゴ',
  'サ': 'ザ',
  'シ': 'ジ',
  'ス': 'ズ',
  'セ': 'ゼ',
  'ソ': 'ゾ',
  'タ': 'ダ',
  'チ': 'ヂ',
  'ツ': 'ヅ',
  'テ': 'デ',
  'ト': 'ド',
  'ハ': 'バ',
  'ヒ': 'ビ',
  'フ': 'ブ',
  'ヘ': 'ベ',
  'ホ': 'ボ',
  'ウ': 'ヴ',
  'ワ': 'ヷ',
  'ヲ': 'ヺ',
};

/// 「全角カタカナ + 半角半濁点(ﾟ)」→ 合成済み半濁音 1 文字。
const Map<String, String> _handakutenCombinations = <String, String>{
  'ハ': 'パ',
  'ヒ': 'ピ',
  'フ': 'プ',
  'ヘ': 'ペ',
  'ホ': 'ポ',
};

/// かな表記ゆれを吸収する。
///
/// * ひらがな U+3041..U+3096 → +0x60 でカタカナ（ゕ/ゖ → ヵ/ヶ を含む）
/// * 半角カナ U+FF66..U+FF9F → 全角カタカナ（表引き）
/// * 濁点 ﾞ / 半濁点 ﾟ は直前の半角カナと結合して ガ/パ 等の合成文字へ
/// * それ以外（ASCII・漢字・全角カタカナ）は不変
String foldKana(String input) {
  if (input.isEmpty) return input;
  final runes = input.runes.toList(growable: false);
  final sb = StringBuffer();

  for (var i = 0; i < runes.length; i++) {
    final code = runes[i];

    // ひらがな → カタカナ
    if (code >= 0x3041 && code <= 0x3096) {
      sb.writeCharCode(code + 0x60);
      continue;
    }

    // 半角カナ → 全角カタカナ
    if (code >= 0xFF66 && code <= 0xFF9F) {
      if (code == _dakuten) {
        // 結合先が無い単独の濁点は全角の間隔用濁点へ
        sb.write('\u309B');
        continue;
      }
      if (code == _handakuten) {
        sb.write('\u309C');
        continue;
      }

      final kana = _halfwidthToFullwidth[code]!;
      final next = i + 1 < runes.length ? runes[i + 1] : null;

      if (next == _dakuten) {
        final composed = _dakutenCombinations[kana];
        if (composed != null) {
          sb.write(composed);
          i++; // 濁点を消費
          continue;
        }
      } else if (next == _handakuten) {
        final composed = _handakutenCombinations[kana];
        if (composed != null) {
          sb.write(composed);
          i++; // 半濁点を消費
          continue;
        }
      }

      sb.write(kana);
      continue;
    }

    // ASCII・漢字・全角カタカナ等はそのまま
    sb.writeCharCode(code);
  }

  return sb.toString();
}
