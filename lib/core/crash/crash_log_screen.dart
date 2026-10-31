import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpg_todo/core/crash/crash_log_entry.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 端末内に残したクラッシュログの閲覧・コピー画面。
class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key, this.repository, this.now});

  /// 既定は端末内ファイル実装（[crashLogger] と同一の保存先）。
  final CrashLogRepository? repository;

  /// サマリーの日時整形に使う現在時刻（試練で固定する）。
  final DateTime Function()? now;

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  late final CrashLogRepository _repository =
      widget.repository ?? crashLogger.repository;
  List<CrashLogEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _repository.loadAll();
    if (!mounted) return;
    setState(() => _entries = loaded);
  }

  Future<void> _copy() async {
    final entries = _entries ?? const <CrashLogEntry>[];
    final text = entries.map((e) => jsonEncode(e.toJson())).join('\n');
    await Clipboard.setData(
        ClipboardData(text: text.isEmpty ? '（記録なし）' : text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('クリップボードへコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final summary = entries == null
        ? ''
        : summarize(entries, now: widget.now) ?? '前回の異常終了は記録されていません';
    final recentEntries =
        entries == null ? const <CrashLogEntry>[] : recent(entries, limit: 20);

    return Scaffold(
      key: AppKeys.crashLogScreen,
      appBar: AppBar(
        title: const Text('不具合の報告'),
        actions: [
          IconButton(
            key: AppKeys.crashLogCopyButton,
            tooltip: 'クリップボードへコピー',
            icon: const Icon(Icons.copy_all),
            onPressed: entries == null ? null : _copy,
          ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    summary,
                    key: AppKeys.crashLogSummary,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '記録は端末内に最大50件まで保存されます（本文は先頭200字・スタックは先頭10フレームのみ）。'
                    '個人情報は含まれません。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                  ),
                ),
                if (recentEntries.isEmpty)
                  const Padding(
                    key: AppKeys.crashLogEmpty,
                    padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Text(
                        '記録された不具合はありません',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF777777)),
                      ),
                    ),
                  )
                else
                  for (final entry in recentEntries)
                    ListTile(
                      dense: true,
                      title: Text(
                        entry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_stamp(entry.timestamp)} ・ ${entry.kind}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
              ],
            ),
    );
  }

  static String _stamp(DateTime ts) {
    final l = ts.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}/${two(l.month)}/${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

/// 設定ハブに置く「不具合の報告」導線。記録が1件以上の時だけ件数を添える。
class CrashReportTile extends StatefulWidget {
  const CrashReportTile({super.key, this.repository});

  final CrashLogRepository? repository;

  @override
  State<CrashReportTile> createState() => _CrashReportTileState();
}

class _CrashReportTileState extends State<CrashReportTile> {
  late final CrashLogRepository _repository =
      widget.repository ?? crashLogger.repository;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repository.loadAll();
    if (!mounted) return;
    setState(() => _count = entries.length);
  }

  @override
  Widget build(BuildContext context) {
    final title = _count > 0 ? '不具合の報告 ($_count)' : '不具合の報告';
    return ListTile(
      key: AppKeys.crashReportEntryFromSettings,
      title: Text(title),
      subtitle: const Text('端末内に残ったエラー記録の閲覧・コピー'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CrashLogScreen(repository: _repository),
        ),
      ),
    );
  }
}
