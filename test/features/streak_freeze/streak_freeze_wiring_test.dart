import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 配線検証（ソース断言）— 設定ハブからお休み券画面へ到達できること。
void main() {
  test('設定ハブに 連続記録お休み券 の導線がある', () {
    final source =
        File('lib/features/settings/presentation/settings_hub_screen.dart')
            .readAsStringSync();
    expect(source, contains("title: const Text('連続記録お休み券')"));
    expect(source, contains('StreakFreezeKeys.entryFromSettings'));
    expect(source, contains('const StreakFreezeScreen()'));
  });

  test('PlayerViewModel が切断時に提案を生成し復元APIを持つ', () {
    final source =
        File('lib/features/player/viewmodels/player_view_model.dart')
            .readAsStringSync();
    expect(source, contains('_pendingStreakFreezeOffer = StreakFreezeOffer('));
    expect(source, contains('bool applyStreakFreeze(DateTime now)'));
    expect(source, contains('clearPendingStreakFreezeOffer'));
  });

  test('お休み券はプレイヤー本体とは別boxに永続化する', () {
    final source =
        File('lib/features/streak_freeze/data/streak_freeze_repository.dart')
            .readAsStringSync();
    expect(source, contains("boxName = 'streak_freeze_box'"));
    expect(source, contains("keyName = 'state'"));
  });
}
