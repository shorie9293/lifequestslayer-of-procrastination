// 敵図鑑画面のライト実描画コントラスト走査（薄い宣言。一覧と詳細ダイアログ）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('enemy_catalog_list');
  runScreenFromLedger('enemy_catalog_dialog');
}