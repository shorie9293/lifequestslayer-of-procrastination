// 計画の陣（プロジェクト一覧）のライト／ダーク実描画コントラスト走査（薄い宣言）。
// 判定は test/support/contrast_gate.dart、pump と母数下限は screen_ledger.dart に集約。
import '../../../support/contrast_runner.dart';

void main() {
  runScreenFromLedger('project_list_light');
  runScreenFromLedger('project_list_empty_light');
  runScreenFromLedger('project_list_locked_light');
  runScreenFromLedger('project_list_dark');
}