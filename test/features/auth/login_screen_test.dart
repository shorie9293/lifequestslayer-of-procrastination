import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auth/presentation/login_screen.dart';

void main() {
  group('LoginScreen オフラインモード', () {
    testWidgets('「オフラインモードで続行」ボタンが描画される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      expect(find.text('オフラインモードで続行'), findsOneWidget);
    });

    testWidgets('タップで onContinueOffline コールバックが呼ばれる', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(onContinueOffline: () => tapped = true),
        ),
      );

      await tester.tap(find.text('オフラインモードで続行'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('onContinueOffline 未指定でも描画・タップでクラッシュしない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.tap(find.text('オフラインモードで続行'));
      await tester.pumpAndSettle();

      expect(find.text('オフラインモードで続行'), findsOneWidget);
    });
  });
}
