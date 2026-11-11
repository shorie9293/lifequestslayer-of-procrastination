import 'package:flutter/material.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';

/// 現世をまたぐ受け渡しの「最終送信／最終受信」を可視化する画面。
///
/// 判定材料と表示材料は同一の [CrossAppLinkSnapshot] から取る。
/// 失敗は黙って消さず、理由まで出す（連携が止まっていることに気づけること）。
class CrossAppLinkStatusScreen extends StatefulWidget {
  const CrossAppLinkStatusScreen({super.key, this.recorder});

  /// 記録口（試練での注入用）。未指定ならアプリ共有の実装。
  final CrossAppLinkStatusRecorder? recorder;

  static const Key folderKey = ValueKey<String>('cross_app_link_folder');
  static const Key sentKey = ValueKey<String>('cross_app_link_sent');
  static const Key receivedKey = ValueKey<String>('cross_app_link_received');
  static const Key refreshKey = ValueKey<String>('cross_app_link_refresh');

  @override
  State<CrossAppLinkStatusScreen> createState() =>
      _CrossAppLinkStatusScreenState();
}

class _CrossAppLinkStatusScreenState extends State<CrossAppLinkStatusScreen> {
  CrossAppLinkSnapshot _snapshot = CrossAppLinkSnapshot.empty;
  bool _loading = true;

  CrossAppLinkStatusRecorder get _recorder =>
      widget.recorder ?? CrossAppLinkStatusRecorder.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshot = await _recorder.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('連携状況'),
        actions: [
          IconButton(
            key: CrossAppLinkStatusScreen.refreshKey,
            icon: const Icon(Icons.refresh),
            tooltip: '再読込',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '現世（アプリ）をまたぐ受け渡しの記録です。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '5つの現世で同じフォルダを選ぶと連携が成立します。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _row(
                  context,
                  key: CrossAppLinkStatusScreen.folderKey,
                  label: '共有フォルダ',
                  value: CrossAppLinkStatusText.folder(
                    _snapshot.sharedFolderReady,
                  ),
                  detail: '',
                ),
                _row(
                  context,
                  key: CrossAppLinkStatusScreen.sentKey,
                  label: '最終送信',
                  value: CrossAppLinkStatusText.row(_snapshot.lastSent),
                  detail: CrossAppLinkStatusText.detail(_snapshot.lastSent),
                ),
                _row(
                  context,
                  key: CrossAppLinkStatusScreen.receivedKey,
                  label: '最終受信',
                  value: CrossAppLinkStatusText.row(_snapshot.lastReceived),
                  detail: CrossAppLinkStatusText.detail(
                    _snapshot.lastReceived,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '送信・受信は共有フォルダへの書込／読取のたびに更新されます。'
                  '「未記録」はまだ一度も受け渡しが起きていない状態です。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
    required String detail,
  }) {
    final theme = Theme.of(context);
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.bodyLarge),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
