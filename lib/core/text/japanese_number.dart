/// 日本語入力（全角数字・全角カンマ）を許容する数値パースの純粋関数群。
///
/// 現世共通の基盤。外部依存ゼロ・状態ゼロ。
///
/// 背景（改善提案#215）: TextField に全角数字「３０」を入力すると
/// `int.tryParse` が黙って null を返し、目標時間が未設定（=0扱い）になっていた。
/// 利用者は入力したつもりでいるため、これは「黙って値を捨てる」欠陥である。
///
/// 使い分け:
/// - 利用者が直接タイプする入力欄 → 本クラスを使う
/// - JSON・保存値・正規表現キャプチャ等の機械データ → `int.tryParse` のままでよい
class JapaneseNumber {
  const JapaneseNumber._();

  /// 全角数字・全角カンマ・全角空白・全角マイナスを ASCII へ正規化する。
  ///
  /// - ０-９ (U+FF10-FF19) → 0-9
  /// - ，(U+FF0C) と , (U+002C) → 除去
  /// - 　(U+3000) → 半角空白
  /// - －(U+FF0D) と −(U+2212) → -
  /// - 前後の空白を除去
  static String normalizeDigits(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        // 全角数字 → 半角数字
        buffer.writeCharCode(rune - 0xFEE0);
      } else if (rune == 0xFF0C || rune == 0x2C) {
        // カンマ（全角・半角）は桁区切りとして捨てる
        continue;
      } else if (rune == 0x3000) {
        buffer.write(' ');
      } else if (rune == 0xFF0D || rune == 0x2212) {
        buffer.write('-');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim();
  }

  /// 正規化してから整数へ変換する。解釈不能・空文字は null。
  ///
  /// `'１２３'` → 123 / `'１，２３４'` → 1234 / `'－５'` → -5
  /// `''`・`null`・`'　'`・`'123abc'` → null
  static int? tryParseInt(String? raw) {
    if (raw == null) return null;
    final normalized = normalizeDigits(raw);
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  /// 解釈できない場合に [fallback] を返す版。
  static int parseIntOr(String? raw, int fallback) =>
      tryParseInt(raw) ?? fallback;
}
