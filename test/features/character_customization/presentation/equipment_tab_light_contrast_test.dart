// キャラクター装備タブのライト／ダーク実描画コントラスト走査（薄い宣言）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('equipment_light_initial');
  runScreenFromLedger('equipment_light_list');
  runScreenFromLedger('equipment_light_preview');
  runScreenFromLedger('equipment_dark_list');
}