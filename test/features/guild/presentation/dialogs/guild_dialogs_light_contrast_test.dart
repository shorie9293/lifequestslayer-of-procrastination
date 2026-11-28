// 寄合所の各ダイアログのライト／ダーク実描画コントラスト走査（薄い宣言）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('create_task_dialog_light');
  runScreenFromLedger('bulk_create_dialog_light');
  runScreenFromLedger('tutorial_reset_dialog_light');
  runScreenFromLedger('create_task_dialog_dark');
}