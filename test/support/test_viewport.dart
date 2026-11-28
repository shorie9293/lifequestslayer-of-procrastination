// 試練の画面サイズを実機相当に設定するヘルパ。
//
// これまでの走査試練は Size(1000〜1200, 4000〜5000) / devicePixelRatio 1.0 と、
// 実機より遥かに広い「無理やりな」キャンバスを使っていた。実機の論理幅は概ね
// 360〜430dp である。ここでは実機相当（既定 幅360dp・devicePixelRatio 2.0）を
// 設定し、実効 dp を実機より広げない。縦は内容が収まるよう十分に高く取る。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実機相当の論理幅（dp）。Pixel 等の最小級フラッグシップに合わせる。
const double kDeviceWidthDp = 360.0;

/// 実機相当の devicePixelRatio。
const double kDevicePixelRatio = 2.0;

/// 実機相当のタテ（dp）。縦長画面をスクロール無しで走査するため余裕を取る。
const double kDeviceHeightDp = 3000.0;

/// 試練の画面サイズを実機相当へ設定する。
///
/// [widthDp] を省略すると 360dp（実機最小級）。論理幅を実機より広げるのは禁止だが、
/// Flutter の試練用フォント（Ahem＝全字が全角相当の幅）は実フォントより文字が広く、
/// 360dp では横幅の RenderFlex が溢れる画面がある。その場合のみ、実機の論理幅として
/// 現実的な範囲（〜430dp）で画面ごとに幅を明示して回避する（溢れ＝実レイアウトの禍津
/// ではない、試練フォント由来の見かけの溢れのため）。
void useRealDeviceViewport(
  WidgetTester tester, {
  double widthDp = kDeviceWidthDp,
  double heightDp = kDeviceHeightDp,
  double devicePixelRatio = kDevicePixelRatio,
}) {
  tester.view.physicalSize =
      Size(widthDp * devicePixelRatio, heightDp * devicePixelRatio);
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}