// 振り返りの杜のライト実描画コントラスト走査＋ライトテーマ文字色契約（薄い宣言）。
// 走査の登録は test/support/reflection_grove_gate.dart（Hive 前提）、テーマ契約の
// 判定は test/support/theme_contract.dart に集約し、本ファイルは呼ぶだけ。
import '../../../support/reflection_grove_gate.dart';
import '../../../support/theme_contract.dart';

void main() {
  runReflectionGroveGate();
  runLightThemeContrastContract();
}