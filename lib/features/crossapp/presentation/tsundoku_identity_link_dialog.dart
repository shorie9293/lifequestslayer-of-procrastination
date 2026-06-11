import 'package:flutter/material.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_settings_repository.dart';

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
          const SizedBox(height: 16),
          TextField(
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
          TextButton(
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
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
      ],
    );
  }

  /// ダイアログを表示し、設定された user_id（または null）を返す
  static Future<String?> show(BuildContext context, {String? currentUserId}) {
    return showDialog<String>(
      context: context,
      builder: (_) => TsundokuIdentityLinkDialog(currentUserId: currentUserId),
    );
  }
}
