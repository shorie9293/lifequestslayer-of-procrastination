// 町タブのライト／ダーク実描画コントラスト走査（薄い宣言）。
//
// 判定ロジックは test/support/contrast_gate.dart、pump と母数下限は
// test/support/screen_ledger.dart に集約済み。ここは台帳キーを呼ぶだけ。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('town_light');
  runScreenFromLedger('town_dark');
}