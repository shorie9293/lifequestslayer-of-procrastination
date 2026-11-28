// 冒険の戦績シェアカードのライト／ダーク実描画コントラスト走査（薄い宣言）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('adventure_share_card_light');
  runScreenFromLedger('adventure_share_card_dark');
}