import 'package:flutter/services.dart';

/// 主要操作の軽い触覚フィードバック。
///
/// **await 禁止・[Future.ignore] で捨てる** — `flutter_test` では
/// プラットフォームチャネルが解決されず Future が永久に完了しないことがあり、
/// await すると試練がハングする（既知の禍津）。
void hapticTap() => HapticFeedback.selectionClick().ignore();
