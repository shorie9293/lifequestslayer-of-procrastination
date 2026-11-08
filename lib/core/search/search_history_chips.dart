// 検索語の履歴チップ。
//
// 履歴が空なら何も描かない。タップされた語を onSelected で返すだけの
// 薄い表示部品で、検索欄や状態には一切触れない。

import 'package:flutter/material.dart';

class SearchHistoryChips extends StatelessWidget {
  const SearchHistoryChips({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  /// 新しい順の検索語。
  final List<String> entries;

  /// チップがタップされたときに語を返す。
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final entry in entries)
            ActionChip(
              key: ValueKey('search history chip $entry'),
              label: Text(entry),
              onPressed: () => onSelected(entry),
            ),
        ],
      ),
    );
  }
}
