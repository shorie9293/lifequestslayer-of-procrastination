import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/about/domain/about_info.dart';
import 'package:rpg_todo/features/about/domain/external_url_opener.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';
import 'package:rpg_todo/features/about/presentation/about_screen.dart';

/// 「アプリについて」の外部リンク導線（url_launcher 抽象越し）の試練。
///
/// 実網・実ブラウザは撃たない。`urlOpener` にフェイクを注入し、
/// 「どの URI が渡されたか」「失敗時にコピー導線へ退避するか」を検証する。
void main() {
  final info = AboutInfo(
    appName: 'テストアプリ',
    version: '9.9.9+99',
    contactEmail: 'test@example.com',
    privacyPolicyUrl: 'https://example.com/privacy',
    tagline: '試練用タグライン',
  );

  Future<void> pumpWith(
    WidgetTester tester, {
    required ExternalUrlOpener opener,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AboutScreen(
          info: info,
          urlOpener: opener,
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pump();
  }

  group('ExternalUrlOpener 純粋ヘルパ', () {
    test('externalUri は前後の空白を除去した URI を返す', () {
      expect(
        externalUri('  https://www.yoppala.in/privacy  '),
        Uri.parse('https://www.yoppala.in/privacy'),
      );
    });

    test('externalUri はスキーム無し・空文字に null を返す', () {
      expect(externalUri('yoppala.in/privacy'), isNull);
      expect(externalUri(''), isNull);
      expect(externalUri('   '), isNull);
    });

    test('mailtoUri は前後の空白を除去して mailto: へ変換する', () {
      expect(
        mailtoUri(' horie.shunta@gmail.com '),
        Uri.parse('mailto:horie.shunta@gmail.com'),
      );
    });
  });

  group('プライバシーポリシーの外部遷移', () {
    testWidgets('タップでポリシーURLが opener へ渡り、ダイアログは開かない', (tester) async {
      final opened = <Uri>[];
      await pumpWith(tester, opener: (uri) async {
        opened.add(uri);
        return true;
      });

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://example.com/privacy')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('opener が false を返したら従来のコピーダイアログへ退避する', (tester) async {
      await pumpWith(tester, opener: (_) async => false);

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('https://example.com/privacy'), findsWidgets);
      expect(find.byKey(AboutAppKeys.copyButton), findsOneWidget);
    });

    testWidgets('opener が例外を投げても画面は壊れず退避する', (tester) async {
      await pumpWith(
        tester,
        opener: (_) async => throw StateError('no browser'),
      );

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('問い合わせの外部遷移', () {
    testWidgets('タップで mailto: URI が opener へ渡る', (tester) async {
      final opened = <Uri>[];
      await pumpWith(tester, opener: (uri) async {
        opened.add(uri);
        return true;
      });

      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('mailto:test@example.com')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('opener が false を返したらコピーダイアログへ退避する', (tester) async {
      await pumpWith(tester, opener: (_) async => false);

      await tester.tap(find.byKey(AboutAppKeys.contactTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('test@example.com'), findsWidgets);
    });

    testWidgets('スキーム無しのURLは opener を撃たずにダイアログへ退避する', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AboutScreen(
            info: AboutInfo(
              appName: 'テストアプリ',
              version: '9.9.9+99',
              contactEmail: 'test@example.com',
              privacyPolicyUrl: 'example.com/privacy',
            ),
            urlOpener: (uri) async {
              opened.add(uri);
              return true;
            },
            clipboardWriter: (_) async {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(AboutAppKeys.privacyTile));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
