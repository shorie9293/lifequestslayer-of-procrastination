import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg_todo/features/about/domain/about_info.dart';
import 'package:rpg_todo/features/about/domain/external_url_opener.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';
import 'package:rpg_todo/features/about/presentation/external_url_launcher.dart';

/// 「アプリについて」画面。
///
/// 暗黙の外部通信はせず、ユーザーのタップ時のみ外部アプリへ渡す。
/// プライバシーポリシーと問い合わせは [ExternalUrlOpener] 越しに開き、
/// 開けなかった場合（false・例外・スキーム無し）は従来の
/// コピー導線（ダイアログ表示＋クリップボード）へ退避する。
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    this.info = kAboutInfo,
    this.clipboardWriter = _defaultClipboardWriter,
    this.urlOpener = launchExternalUrl,
  });

  final AboutInfo info;

  /// クリップボード書き込み口（試練ではインメモリ実装を注入する）。
  final Future<void> Function(String value) clipboardWriter;

  /// 外部URLを開く口（試練ではフェイクを注入する）。
  final ExternalUrlOpener urlOpener;

  static Future<void> _defaultClipboardWriter(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }

  /// 外部アプリで開く。開けなければ（false・例外）コピー導線へ退避する。
  Future<void> _openOrCopy(
    BuildContext context, {
    required Uri? uri,
    required String title,
    required String value,
  }) async {
    var opened = false;
    if (uri != null) {
      try {
        opened = await urlOpener(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    await _showCopyDialog(context, title: title, value: value);
  }

  Future<void> _showCopyDialog(
    BuildContext context, {
    required String title,
    required String value,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SelectableText(value),
        actions: [
          TextButton(
            key: AboutAppKeys.copyButton,
            onPressed: () async {
              // クリップボードは環境により失敗し得るため握りつぶさず通知のみ。
              try {
                await clipboardWriter(value);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('コピーしました')),
                  );
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('コピーに失敗しました')),
                  );
                }
              }
            },
            child: const Text('コピー'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AboutAppKeys.aboutScreen,
      appBar: AppBar(title: const Text('アプリについて')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  info.appName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'v${info.version}',
                  key: AboutAppKeys.versionLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (info.tagline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(info.tagline,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          ListTile(
            key: AboutAppKeys.licenseTile,
            title: const Text('オープンソースライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: info.appName,
              applicationVersion: info.version,
            ),
          ),
          ListTile(
            key: AboutAppKeys.privacyTile,
            title: const Text('プライバシーポリシー'),
            subtitle: const Text('タップでブラウザ表示（開けなければコピー）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openOrCopy(
              context,
              uri: externalUri(info.privacyPolicyUrl),
              title: 'プライバシーポリシー',
              value: info.privacyPolicyUrl,
            ),
          ),
          ListTile(
            key: AboutAppKeys.contactTile,
            title: const Text('問い合わせ'),
            subtitle: const Text('タップでメール作成／開けなければコピー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openOrCopy(
              context,
              uri: mailtoUri(info.contactEmail),
              title: '問い合わせ',
              value: info.contactEmail,
            ),
          ),
        ],
      ),
    );
  }
}
