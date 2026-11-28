// 俯瞰の魔眼画面のライト／ダーク実描画コントラスト走査（薄い宣言）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('overview_calendar_light');
  runScreenFromLedger('overview_kanban_light');
  runScreenFromLedger('overview_locked_light');
  runScreenFromLedger('overview_calendar_dark');
  runScreenFromLedger('overview_kanban_dark');
}