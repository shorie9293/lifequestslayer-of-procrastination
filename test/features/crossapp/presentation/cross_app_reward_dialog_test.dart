// クロス報酬画面の送客導線（送客元アプリを開くボタン）の試練
//
// クロス報酬（tsundoku-quest 連携報酬）を受信した際、送客元アプリへユーザーを
// 誘導する「tsundoku-quest を開く」導線ボタンが存在し、押下時に
// app://open が正しく起動されることを検証する。
// launchUri を注入（DI）して外部依存（url_launcher）を Mock 可能にしている。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_reward_dialog.dart';

void main() {
  group('CrossAppRewardDialog 送客導線', () {
    testWidgets('「tsundoku-quest を開く」ボタンに identifier が付与される',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrossAppRewardDialog(
              totalCoins: 10,
              totalExp: 20,
              newTitles: ['読書の賢者'],
            ),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('btn_open_tsundoku'), findsOneWidget);
      // 可視テキストとアクセシビリティラベルの両方が付与される
      expect(find.text('tsundoku-quest を開く'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('押下時に launchUri が app://open で呼ばれる', (tester) async {
      final launchedUris = <Uri>[];
      Future<bool> fakeLaunch(Uri uri) async {
        launchedUris.add(uri);
        return true;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrossAppRewardDialog(
              totalCoins: 10,
              totalExp: 20,
              newTitles: const ['読書の賢者'],
              launchUri: fakeLaunch,
            ),
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(TextButton, 'tsundoku-quest を開く'),
      );
      await tester.pump();

      expect(launchedUris, [Uri.parse('app://open')]);
    });

    testWidgets('「受け取る」ボタンは引き続き存在する', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrossAppRewardDialog(
              totalCoins: 10,
              totalExp: 0,
              newTitles: [],
            ),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('btn_accept_reward'), findsOneWidget);
      expect(find.text('受け取る'), findsOneWidget);
    });

    testWidgets('launchUri が失敗してもクラッシュしない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrossAppRewardDialog(
              totalCoins: 1,
              totalExp: 0,
              newTitles: const [],
              launchUri: (uri) async => throw Exception('launch failed'),
            ),
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(TextButton, 'tsundoku-quest を開く'),
      );
      await tester.pump();

      // クラッシュせずダイアログの導線ボタンが残る
      expect(find.bySemanticsIdentifier('btn_open_tsundoku'), findsOneWidget);
    });
  });
}
