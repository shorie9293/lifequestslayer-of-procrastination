import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/about/domain/about_info.dart';

void main() {
  group('AboutInfo 不変条件', () {
    test('空のappNameでArgumentError', () {
      expect(
        () => AboutInfo(
          appName: '',
          version: '1.0.0',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: 'https://example.com',
        ),
        throwsArgumentError,
      );
    });

    test('空のversionでArgumentError', () {
      expect(
        () => AboutInfo(
          appName: 'X',
          version: '',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: 'https://example.com',
        ),
        throwsArgumentError,
      );
    });

    test('空のcontactEmailでArgumentError', () {
      expect(
        () => AboutInfo(
          appName: 'X',
          version: '1.0.0',
          contactEmail: '',
          privacyPolicyUrl: 'https://example.com',
        ),
        throwsArgumentError,
      );
    });

    test('空のprivacyPolicyUrlでArgumentError', () {
      expect(
        () => AboutInfo(
          appName: 'X',
          version: '1.0.0',
          contactEmail: 'a@b.c',
          privacyPolicyUrl: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('kAboutInfo 既定値', () {
    test('appName は RPGタスク', () {
      expect(kAboutInfo.appName, 'RPGタスク');
    });

    test('contactEmail は実在の問い合わせ先', () {
      expect(kAboutInfo.contactEmail, 'horie.shunta@gmail.com');
    });

    test('privacyPolicyUrl は yoppala.in のプライバシーポリシー', () {
      expect(kAboutInfo.privacyPolicyUrl, 'https://yoppala.in/privacy');
    });

    test('version は pubspec.yaml と一致する（1.5.51+147）', () {
      expect(kAboutInfo.version, '1.5.51+147');
    });

    test('tagline が空でない', () {
      expect(kAboutInfo.tagline, isNotEmpty);
    });
  });
}
