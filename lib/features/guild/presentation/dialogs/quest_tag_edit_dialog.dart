// クエストの札（タグ）編集ダイアログ
//
// 状態は State 内で完結し、保存時のみ親へ onSave で通知する。
// 検証・加工はドメイン層 QuestTagService に委譲する。

import 'package:flutter/material.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/domain/quest_tag_service.dart';

class QuestTagEditDialog extends StatefulWidget {
  const QuestTagEditDialog({
    super.key,
    required this.taskTitle,
    required this.initialTags,
    required this.onSave,
  });

  /// 編集対象クエストの名前（表示用）
  final String taskTitle;

  /// 開いた時点の札
  final List<String> initialTags;

  /// 保存時に更新後の札一覧を受け取る。キャンセル時は呼ばれない。
  final ValueChanged<List<String>> onSave;

  @override
  State<QuestTagEditDialog> createState() => _QuestTagEditDialogState();
}

class _QuestTagEditDialogState extends State<QuestTagEditDialog> {
  late List<String> _tags;
  final TextEditingController _input = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _tags = QuestTagService.uniqueTags(widget.initialTags);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String? _errorMessage(QuestTagValidation v) {
    switch (v) {
      case QuestTagValidation.empty:
        return '札を入力せよ';
      case QuestTagValidation.tooLong:
        return '12文字まで';
      case QuestTagValidation.duplicate:
        return '同じ札が既にある';
      case QuestTagValidation.ok:
        return null;
    }
  }

  void _addTag() {
    final validation = QuestTagService.validateNew(_input.text, _tags);
    final message = _errorMessage(validation);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() {
      _tags = QuestTagService.withTag(_tags, _input.text);
      _error = null;
      _input.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags = QuestTagService.withoutTag(_tags, tag);
      _error = null;
    });
  }

  void _save() {
    widget.onSave(List<String>.of(_tags));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('札（タグ）の編集'),
          const SizedBox(height: 4),
          Text(
            widget.taskTitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tags.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'まだ札がない。',
                  key: AppKeys.questTagEmpty,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in _tags)
                    Chip(
                      key: AppKeys.questTagChipDelete(tag),
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _removeTag(tag),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              key: AppKeys.questTagInput,
              controller: _input,
              decoration: const InputDecoration(
                hintText: '新しい札（12文字まで）',
                isDense: true,
              ),
              onSubmitted: (_) => _addTag(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  key: AppKeys.questTagError,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: AppKeys.questTagAddButton,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('札を追加'),
                onPressed: _addTag,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: AppKeys.questTagCancelButton,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          key: AppKeys.questTagSaveButton,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
