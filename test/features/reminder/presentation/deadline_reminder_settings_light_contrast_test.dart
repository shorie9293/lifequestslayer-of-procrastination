// 期限リマインダー設定画面のライト／ダーク実描画コントラスト走査（薄い宣言）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('deadline_reminder_light');
  runScreenFromLedger('deadline_reminder_dark');
}