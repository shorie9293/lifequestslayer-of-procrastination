import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg_todo/features/about/domain/about_info.dart';
import 'package:rpg_todo/features/about/presentation/about_app_keys.dart';

/// 「アプリについて」画面。
/// 外部URLを開く通信は一切しない（url_launcher不使用）。
/// URL・メールアドレスはダイアログ表示＋クリップボードコピーのみ。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.info = kAboutInfo});

  final AboutInfo info;

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
                await Clipboard.setData(ClipboardData(text: value));
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
            subtitle: const Text('URLを表示してコピー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCopyDialog(
              context,
              title: 'プライバシーポリシー',
              value: info.privacyPolicyUrl,
            ),
          ),
          ListTile(
            key: AboutAppKeys.contactTile,
            title: const Text('問い合わせ'),
            subtitle: const Text('メールアドレスを表示してコピー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCopyDialog(
              context,
              title: '問い合わせ',
              value: info.contactEmail,
            ),
          ),
        ],
      ),
    );
  }
}
