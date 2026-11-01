// 天浮橋計画 — rpg-task スモークテスト（CI integration-smoke 用）
// 単独実行: flutter test integration_test/smoke_test.dart -d emulator-5554
//
// 目的: 正規起動（main → runZonedGuarded → bootstrap）が実機/エミュレータ上で
// Hive・DI・通知・Firebase・Supabase・ディープリンクの初期化を経て
// MaterialApp まで到達することを最小限で検証する。
// E2E（チュートリアル突破・タスク作成）は rpg_task_create_test.dart / rpg_e2e_tests.dart が担う。
//
// 方針:
// - pumpAndSettle は使わない（常駐アニメーション・実機I/O で settle しない）
// - bootstrap は zone 内で非同期に走るため、MaterialApp の出現を実時間予算で待つ

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rpg_todo/main.dart' as app;

/// 起動初期化（Hive/DI/通知/Firebase/Supabase/クイズ読込）の待ち予算
const Duration _startupBudget = Duration(seconds: 90);

/// pump 1回あたりの実時間ステップ
const Duration _pumpStep = Duration(milliseconds: 250);

/// [finder] がヒットするまで実時間で pump し続ける。
/// ヒットしたら true、予算切れなら false。
Future<bool> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration budget = _startupBudget,
  Duration step = _pumpStep,
}) async {
  final deadline = DateTime.now().add(budget);
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(step);
  }
  return finder.evaluate().isNotEmpty;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('スモーク: 正規起動で MaterialApp が描画される', (tester) async {
    // main() は void（runZonedGuarded 内で bootstrap を await する）。
    // 同期例外のみ拾い、非同期失敗は MaterialApp 未到達として検出する。
    Object? startupError;
    try {
      app.main();
    } catch (e) {
      startupError = e;
    }

    final appFound = await _pumpUntilFound(tester, find.byType(MaterialApp));

    // 初回フレーム後の配線（保留ディープリンク・通知タップ復元）を数フレーム進める
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(
      startupError,
      isNull,
      reason: '起動時の同期例外が無いこと: $startupError',
    );
    expect(
      appFound,
      isTrue,
      reason: '起動初期化が ${_startupBudget.inSeconds} 秒以内に完了し '
          'ウィジェットツリーが構築されること',
    );
    expect(
      find.byType(MaterialApp),
      findsOneWidget,
      reason: 'rpg-task アプリが正常に起動していること',
    );
  });
}
