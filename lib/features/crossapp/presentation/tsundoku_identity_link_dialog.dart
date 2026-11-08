import 'package:flutter/material.dart';
import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_reward_service.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_settings_repository.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// tsundoku-quest 連携設定ダイアログ
///
/// tsundoku user_id の先頭8文字を入力して手動リンクする。
class TsundokuIdentityLinkDialog extends StatefulWidget {
  final String? currentUserId;

  const TsundokuIdentityLinkDialog({super.key, this.currentUserId});

  @override
  State<TsundokuIdentityLinkDialog> createState() =>
      _TsundokuIdentityLinkDialogState();
}

class _TsundokuIdentityLinkDialogState
    extends State<TsundokuIdentityLinkDialog> {
  late TextEditingController _controller;
  final _repository = CrossAppSettingsRepository();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUserId ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 共有フォルダを選んでもらう（初回だけ・以後は自動）。
  Future<void> _chooseFolder() async {
    final store = SharedFileStore.instance;
    final ok = await store.chooseDirectory();
    if (!mounted) return;
    crossAppLinkStatus.value = crossAppLinkStatus.value.copyWith(
      sharedFolderReady: ok,
      clearError: ok,
      lastError: ok ? null : '共有フォルダが選ばれていません',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '共有フォルダを設定しました' : '共有フォルダの設定に失敗しました'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.link, color: Colors.amber),
          SizedBox(width: 8),
          Text('tsundoku-quest 連携設定'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'tsundoku-quest アプリのユーザーID（先頭8文字）を入力してください。\n\n'
            '連携すると、読書の進捗に応じて rpg-task 内で称号や報酬を獲得できます。',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          // 共有フォルダの状態（最終送信/最終受信/失敗）を1つの状態から表示
          ValueListenableBuilder<CrossAppLinkStatus>(
            valueListenable: crossAppLinkStatus,
            builder: (context, status, _) => _SharedStorageStatusBlock(
              status: status,
              onChoose: _chooseFolder,
            ),
          ),
          const SizedBox(height: 16),
          SemanticHelper.textField(
            testId: SemanticHelper.createTestId(
                SemanticTypes.textField, 'tsundoku_user_id'),
            label: 'tsundoku user_id（先頭8桁）',
            child: TextField(
              controller: _controller,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'tsundoku user_id (先頭8桁)',
                hintText: '例: a1b2c3d4',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '現在の連携ID: ${widget.currentUserId}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty)
          SemanticHelper.interactive(
            testId:
                SemanticHelper.createTestId(SemanticTypes.button, 'unlink'),
            label: '連携解除',
            child: TextButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      await _repository.setTsundokuLinkedUserId(null);
                      setState(() => _isSaving = false);
                      if (mounted) {
                        Navigator.of(context).pop(null);
                      }
                    },
              child: const Text('連携解除', style: TextStyle(color: Colors.red)),
            ),
          ),
        SemanticHelper.interactive(
          testId:
              SemanticHelper.createTestId(SemanticTypes.button, 'cancel_link'),
          label: 'キャンセル',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('キャンセル'),
          ),
        ),
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(SemanticTypes.button, 'link'),
          label: '連携する',
          child: ElevatedButton(
            onPressed: _isSaving || _controller.text.trim().isEmpty
                ? null
                : () async {
                    final userId = _controller.text.trim();
                    if (userId.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('8文字で入力してください')),
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    await _repository.setTsundokuLinkedUserId(userId);
                    setState(() => _isSaving = false);
                    if (mounted) {
                      Navigator.of(context).pop(userId);
                    }
                  },
            child: const Text('連携する'),
          ),
        ),
      ],
    );
  }

  /// ダイアログを表示し、設定された user_id（または null）を返す
  // ignore: unused_element — 将来の連携UIから呼び出される予定
  static Future<String?> show(BuildContext context, {String? currentUserId}) {
    return showDialog<String>(
      context: context,
      builder: (_) => TsundokuIdentityLinkDialog(currentUserId: currentUserId),
    );
  }
}

/// 共有フォルダの状態表示（最終送信/最終受信/失敗）。
///
/// 判定材料と表示材料は**同じ状態オブジェクト**から取る（表示と判定の分裂を防ぐ）。
class _SharedStorageStatusBlock extends StatelessWidget {
  const _SharedStorageStatusBlock({
    required this.status,
    required this.onChoose,
  });

  final CrossAppLinkStatus status;
  final Future<void> Function() onChoose;

  String _fmt(DateTime? t) {
    if (t == null) return '—';
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.month}/${local.day} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = status.isHealthy ? Colors.greenAccent : Colors.orangeAccent;
    final label = status.sharedFolderReady ? '共有フォルダ: 設定済み' : '共有フォルダ: 未設定';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isHealthy ? Icons.check_circle : Icons.error_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '最終送信: ${_fmt(status.lastSentAt)}　最終受信: ${_fmt(status.lastReceivedAt)}',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          if (status.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              '直近の失敗: ${status.lastError}',
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ],
          if (!status.sharedFolderReady)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onChoose(),
                child: const Text('共有フォルダを選ぶ'),
              ),
            ),
        ],
      ),
    );
  }
}
