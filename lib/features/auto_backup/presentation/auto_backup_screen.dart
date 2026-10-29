import 'package:flutter/material.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_app_keys.dart';

/// 自動バックアップの閲覧・復元・共有画面。
///
/// 復元・共有の実装は任意注入。未注入ならその導線自体を出さない
/// （既存試練・既存画面との後方互換）。
class AutoBackupScreen extends StatefulWidget {
  const AutoBackupScreen({
    super.key,
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.restorer,
    this.sharer,
    this.onBackupNow,
    this.now,
  });

  final AutoBackupStore store;
  final AutoBackupPolicy policy;
  final AutoBackupRestorer? restorer;
  final AutoBackupSharer? sharer;

  /// 「今すぐバックアップ」の実行本体。未指定ならボタンを出さない。
  final Future<void> Function()? onBackupNow;

  /// 時計（試練での固定用）。未指定なら [DateTime.now]。
  final DateTime Function()? now;

  @override
  State<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends State<AutoBackupScreen> {
  late final AutoBackupPresenter _presenter =
      AutoBackupPresenter(keep: widget.policy.keep);

  List<AutoBackupRow> _rows = const [];
  Map<String, String?> _contents = const {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.store.list();
      final contents = <String, String?>{};
      for (final entry in entries) {
        contents[entry.fileName] = await widget.store.read(entry.fileName);
      }
      final rows = _presenter.buildRows(entries: entries, contents: contents);
      if (!mounted) return;
      setState(() {
        _contents = contents;
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
      _snack('バックアップの読み込みに失敗しました: $e');
    }
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRestore(AutoBackupRow row) async {
    final restorer = widget.restorer;
    if (restorer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: AutoBackupKeys.confirmDialog,
        title: const Text('復元の確認'),
        content: const Text(
          'このバックアップから復元しますか？現在のデータは先に自動バックアップされます',
        ),
        actions: [
          TextButton(
            key: AutoBackupKeys.cancelRestoreButton,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: AutoBackupKeys.confirmRestoreButton,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await restorer.restore(row.entry.fileName);
      if (!mounted) return;
      _snack(result.message ?? (result.ok ? '復元しました' : '復元に失敗しました'));
      if (result.ok) await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('復元に失敗しました: $e');
    }
  }

  Future<void> _share(AutoBackupRow row) async {
    final sharer = widget.sharer;
    if (sharer == null) return;
    try {
      await sharer.share(
        row.entry.fileName,
        _contents[row.entry.fileName] ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('共有に失敗しました: $e');
    }
  }

  Future<void> _backupNow() async {
    final action = widget.onBackupNow;
    if (action == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (!mounted) return;
      _snack('バックアップしました');
    } catch (e) {
      if (!mounted) return;
      _snack('バックアップに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AutoBackupKeys.screen,
      appBar: AppBar(title: const Text('自動バックアップ')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: AutoBackupKeys.loading),
      );
    }
    final header = widget.onBackupNow == null
        ? null
        : Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              key: AutoBackupKeys.backupNowButton,
              onPressed: _busy ? null : _backupNow,
              icon: const Icon(Icons.backup),
              label: const Text('今すぐバックアップ'),
            ),
          );
    if (_rows.isEmpty) {
      return Column(
        children: [
          if (header != null) header,
          Expanded(
            child: Center(
              child: Text(
                'バックアップはまだありません',
                key: AutoBackupKeys.empty,
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      key: AutoBackupKeys.list,
      children: [
        if (header != null) header,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            _presenter.retentionLabel(_rows.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (var i = 0; i < _rows.length; i++) _buildRow(i, _rows[i]),
      ],
    );
  }

  Widget _buildRow(int index, AutoBackupRow row) {
    return ListTile(
      key: AutoBackupKeys.row(index),
      title: Text(row.displayLabel),
      subtitle: Text(row.entry.fileName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.sharer != null)
            IconButton(
              key: AutoBackupKeys.shareButton(index),
              tooltip: 'このバックアップを共有',
              icon: const Icon(Icons.share),
              onPressed: () => _share(row),
            ),
          if (widget.restorer != null && row.restorable)
            IconButton(
              key: AutoBackupKeys.restoreButton(index),
              tooltip: 'このバックアップから復元',
              icon: const Icon(Icons.restore),
              onPressed: () => _confirmRestore(row),
            ),
        ],
      ),
    );
  }
}
