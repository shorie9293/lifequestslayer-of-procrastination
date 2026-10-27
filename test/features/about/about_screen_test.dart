import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/about/domain/about_info.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';
import 'package:rpg_todo/features/about/presentation/about_screen.dart';

String? _mockClipboard;

void main() {
  final info = AboutInfo(
    appName: 'テストアプリ',
    version: '9.9.9+99',
    contactEmail: 'test@example.com',
    privacyPolicyUrl: 'https://example.com/privacy',
    tagline: 'テスト用タグライン',
  );

  Future<void> pump(WidgetTester tester) async {
    // Clipboard.setData が fake async 内で完了するよう platform をモック。
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (message) async {
        if (message.method == 'Clipboard.setData') {
          _mockClipboard =
              (message.arguments as Map<String, dynamic>)['text'] as String?;
        }
        return null;
      },
    );
    // 外部ブラウザは試練で撃てないため、opener は常に false を返すフェイクを注入し
    // 従来のコピー導線（ダイアログ）を検証する。
    await tester.pumpWidget(MaterialApp(
      home: AboutScreen(info: info, urlOpener: (_) async => false),
    ));
    await tester.pump();
  }

  testWidgets('注入した info の version が versionLabel に表示される', (tester) async {
    await pump(tester);
    expect(find.text('テストアプリ'), findsOneWidget);
    expect(find.byKey(AboutAppKeys.versionLabel), findsOneWidget);
    expect(find.text('v9.9.9+99'), findsOneWidget);
  });

  testWidgets('ライセンスタイル tap で LicensePage が push される', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AboutAppKeys.licenseTile));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('プライバシータイル tap で URL がダイアログに表示される', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AboutAppKeys.privacyTile));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('https://example.com/privacy'), findsOneWidget);
  });

  testWidgets('プライバシーURLコピーで SnackBar が出る', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AboutAppKeys.privacyTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AboutAppKeys.copyButton));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(_mockClipboard, 'https://example.com/privacy');
  });

  testWidgets('問い合わせタイル tap でメールアドレスがダイアログに表示される', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AboutAppKeys.contactTile));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
  });

  testWidgets('既定インスタンスで構築できる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();
    expect(find.byKey(AboutAppKeys.aboutScreen), findsOneWidget);
    expect(find.byKey(AboutAppKeys.licenseTile), findsOneWidget);
    expect(find.byKey(AboutAppKeys.privacyTile), findsOneWidget);
    expect(find.byKey(AboutAppKeys.contactTile), findsOneWidget);
  });
}
