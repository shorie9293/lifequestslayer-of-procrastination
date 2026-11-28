// 全画面一括のコントラスト走査門（画面台帳を丸ごと走査する 1 本）。
//
// screen_ledger.dart に画面を 1 件足せば、この門が自動的に拾って走査する。
// 個別画面ファイルは各キーを呼ぶが、この一括門は「追加漏れ」を防ぐ安全網。
import 'contrast_runner.dart';

void main() {
  runAllScreenCases();
}