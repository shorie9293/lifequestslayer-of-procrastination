import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'package:rpg_todo/features/google_todo/data/google_todo_gateway.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';

import 'google_todo_keys.dart';

/// 画面の進行状態。
enum GoogleTodoPhase { loading, notLinked, linked, error }

/// Google ToDo 連携の設定画面。
///
/// [gateway]・[launchUrl]・[clock] を注入できるので、Provider/端末API に
/// 依存せず試練できる。本番は設定画面から開く。
class GoogleTodoLinkScreen extends StatefulWidget {
  const GoogleTodoLinkScreen({
    super.key,
    this.gateway,
    this.launchUrl,
    this.clock,
  });

  /// 通信実装。未指定時は Edge Function 実装。
  final GoogleTodoGateway? gateway;

  /// 外部ブラウザ起動（試練ではフェイク）。
  final Future<bool> Function(Uri uri)? launchUrl;

  /// 現在時刻（試練用に固定できる）。
  final DateTime Function()? clock;

  @override
  State<GoogleTodoLinkScreen> createState() => _GoogleTodoLinkScreenState();
}

class _GoogleTodoLinkScreenState extends State<GoogleTodoLinkScreen> {
  late final GoogleTodoGateway _gateway;
  late final DateTime Function() _clock;

  GoogleTodoPhase _phase = GoogleTodoPhase.loading;
  GoogleTodoStatus _status = GoogleTodoStatus.notLinked;
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? EdgeFunctionGoogleTodoGateway();
    _clock = widget.clock ?? DateTime.now;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _phase = GoogleTodoPhase.loading;
      _error = '';
    });
    try {
      final status = await _gateway.fetchStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _phase = status.linked ? GoogleTodoPhase.linked : GoogleTodoPhase.notLinked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is GoogleTodoException ? e.message : '状態を取得できませんでした';
        _phase = GoogleTodoPhase.error;
      });
    }
  }

  Future<void> _startLink() async {
    await _run(() async {
      final url = await _gateway.startLink();
      final launcherFn = widget.launchUrl ??
          (uri) => launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
      final opened = await launcherFn(Uri.parse(url));
      if (!mounted) return;
      if (opened) {
        _showSnack('ブラウザで許可すると連携が完了します。戻ったら再読み込みしてください。');
      } else {
        _showSnack('ブラウザを開けませんでした。もう一度お試しください。');
      }
    });
  }

  Future<void> _syncNow() async {
    await _run(() async {
      final result = await _gateway.sync();
      if (!mounted) return;
      _showSnack(
        result.ok ? '同期しました（${result.summary}）' : '${result.summary}: ${result.failures.first}',
      );
      await _load();
    });
  }

  Future<void> _chooseList() async {
    List<GoogleTodoList> lists;
    try {
      lists = await _gateway.fetchLists();
    } catch (e) {
      _showSnack(e is GoogleTodoException ? e.message : 'タスクリストを取得できませんでした');
      return;
    }
    if (!mounted) return;
    if (lists.isEmpty) {
      _showSnack('Google側にタスクリストがありません');
      return;
    }
    final picked = await showDialog<GoogleTodoList>(
      context: context,
      builder: (context) => SimpleDialog(
        key: GoogleTodoKeys.listPicker,
        title: const Text('同期するタスクリスト'),
        children: [
          for (final list in lists)
            SimpleDialogOption(
              key: GoogleTodoKeys.listOption(list.id),
              onPressed: () => Navigator.of(context).pop(list),
              child: Text(list.title),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _run(() async {
      await _gateway.selectList(id: picked.id, title: picked.title);
      await _load();
    });
  }

  Future<void> _unlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: GoogleTodoKeys.unlinkConfirm,
        title: const Text('Google ToDo との連携を解除しますか？'),
        content: const Text('クエストはアプリに残ります。Google側のタスクも消えません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('解除する')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _gateway.unlink();
      await _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        _showSnack(e is GoogleTodoException ? e.message : '処理に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        key: GoogleTodoKeys.screen,
        appBar: AppBar(
          title: const Text('Google ToDo 連携'),
          actions: [
            IconButton(
              key: GoogleTodoKeys.retryButton,
              tooltip: '再読み込み',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case GoogleTodoPhase.loading:
        return const Center(
          key: GoogleTodoKeys.loading,
          child: CircularProgressIndicator(),
        );
      case GoogleTodoPhase.error:
        return _message(
          icon: Icons.cloud_off,
          title: '連携状態を取得できませんでした',
          body: _error,
          action: FilledButton(
            key: GoogleTodoKeys.retryInlineButton,
            onPressed: _load,
            child: const Text('再試行'),
          ),
        );
      case GoogleTodoPhase.notLinked:
        return _buildNotLinked(context);
      case GoogleTodoPhase.linked:
        return _buildLinked(context);
    }
  }

  Widget _buildNotLinked(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Icon(Icons.task_alt, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Google ToDo とクエストを双方向に同期します',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          '札「$googleTodoTag」を付けたクエストが同期対象です。\n'
          'Google側のタスクは寄合所に未受注で並びます。期限は当日23:59（日本時間）として扱います。',
          key: GoogleTodoKeys.notLinkedExplain,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SemanticHelper.interactive(
          testId: 'btn_google_todo_link',
          label: 'Google ToDo と連携する',
          child: FilledButton.icon(
            key: GoogleTodoKeys.linkButton,
            onPressed: _busy ? null : _startLink,
            icon: const Icon(Icons.link),
            label: const Text('Google ToDo と連携する'),
          ),
        ),
      ],
    );
  }

  Widget _buildLinked(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(
              _status.email ?? 'Google アカウント',
              key: GoogleTodoKeys.accountLabel,
            ),
            subtitle: Text(
              _status.listTitle ?? '既定のタスクリスト',
              key: GoogleTodoKeys.listLabel,
            ),
            trailing: TextButton(
              key: GoogleTodoKeys.changeListButton,
              onPressed: _busy ? null : _chooseList,
              child: const Text('変更'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _status.describeSync(_clock()),
          key: GoogleTodoKeys.syncStateLabel,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SemanticHelper.interactive(
          testId: 'btn_google_todo_sync',
          label: '今すぐ同期する',
          child: FilledButton.icon(
            key: GoogleTodoKeys.syncButton,
            onPressed: _busy ? null : _syncNow,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('今すぐ同期する'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '同期の規則: 札「$googleTodoTag」を持つクエストだけが対象です。'
          'どちらかで完了にすると両方完了になります。'
          'Google側で削除したタスクはクエストの「取消」になります。',
          key: GoogleTodoKeys.ruleExplain,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        TextButton.icon(
          key: GoogleTodoKeys.unlinkButton,
          onPressed: _busy ? null : _unlink,
          icon: const Icon(Icons.link_off),
          label: const Text('連携を解除する'),
        ),
      ],
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              key: GoogleTodoKeys.errorState,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
