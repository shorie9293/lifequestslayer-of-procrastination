/// 「アプリについて」画面に表示するアプリ情報の不変オブジェクト。
class AboutInfo {
  /// 不変条件: 全文字列フィールドは空文字禁止。
  /// 検証は非constコンストラクタ本体で行う（ArgumentError）。
  AboutInfo({
    required this.appName,
    required this.version,
    required this.contactEmail,
    required this.privacyPolicyUrl,
    this.tagline = '',
  }) {
    if (appName.isEmpty) {
      throw ArgumentError('appName must not be empty');
    }
    if (version.isEmpty) {
      throw ArgumentError('version must not be empty');
    }
    if (contactEmail.isEmpty) {
      throw ArgumentError('contactEmail must not be empty');
    }
    if (privacyPolicyUrl.isEmpty) {
      throw ArgumentError('privacyPolicyUrl must not be empty');
    }
  }

  /// 検証済みの値だけが通す内部constコンストラクタ（既定値専用）。
  const AboutInfo._trusted(
    this.appName,
    this.version,
    this.contactEmail,
    this.privacyPolicyUrl,
    this.tagline,
  );

  final String appName;
  final String version;
  final String contactEmail;
  final String privacyPolicyUrl;
  final String tagline;
}

/// 既定のアプリ情報。version は pubspec.yaml と一致することを
/// test/features/about/about_version_sync_test.dart が担保する。
const kAboutInfo = AboutInfo._trusted(
  'RPGタスク',
  '1.5.51+147',
  'horie.shunta@gmail.com',
  'https://yoppala.in/privacy',
  'クエストで人生を鍛える、冒険型タスク管理',
);
