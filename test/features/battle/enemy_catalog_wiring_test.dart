// 敵討伐図鑑の配線試練: 討伐戦績画面の AppBar から図鑑が開けること。
// records が空でも導線は常に表示される。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';

void main() {
  testWidgets('戦績0件でも図鑑導線が表示され、タップで図鑑画面が開く',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BattleRecordScreen(
          repository: InMemoryBattleRecordRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 空状態でも AppBar の導線は常に存在する
    expect(find.byKey(AppKeys.enemyCatalogEntry), findsOneWidget);
    expect(find.byKey(AppKeys.battleRecordEmpty), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.enemyCatalogEntry));
    await tester.pumpAndSettle();

    // 図鑑画面（17体の雛形・全未討伐）が表示されている
    expect(find.byKey(AppKeys.enemyCatalogScreen), findsOneWidget);
    expect(find.byKey(AppKeys.enemyCatalogGrid), findsOneWidget);
    expect(find.textContaining('0 / 17 種'), findsOneWidget);
  });
}
