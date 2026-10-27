import 'package:url_launcher/url_launcher.dart';

/// 端末の外部アプリ（ブラウザ・メール等）で URI を開く既定実装。
///
/// 失敗（未対応プラットフォーム・開けるアプリ無し・プラグイン未初期化）は
/// 例外を漏らさず `false` を返す。呼び出し側は `false` を受けて
/// 従来のコピー導線（ダイアログ）へ退避する。
Future<bool> launchExternalUrl(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
