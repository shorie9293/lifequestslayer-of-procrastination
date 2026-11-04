import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/input/unsaved_changes.dart';

void main() {
  group('UnsavedChangesGuard.isDirty', () {
    test('同一文字列は未変更', () {
      expect(UnsavedChangesGuard.isDirty('クエスト', 'クエスト'), isFalse);
    });

    test('末尾の空白・改行だけの差は未変更', () {
      expect(UnsavedChangesGuard.isDirty('クエスト', ' クエスト\n'), isFalse);
    });

    test('本文が変われば変更あり', () {
      expect(UnsavedChangesGuard.isDirty('', '書きかけ'), isTrue);
      expect(UnsavedChangesGuard.isDirty('書きかけ', '書きかけの長文'), isTrue);
    });

    test('空白のみの入力は未変更（誤操作で確認を出さない）', () {
      expect(UnsavedChangesGuard.isDirty('', '   '), isFalse);
    });
  });

  group('UnsavedChangesGuard.isAnyDirty', () {
    test('全項目が同一なら未変更', () {
      expect(
        UnsavedChangesGuard.isAnyDirty(
          {'title': '討伐', 'memo': 'memo'},
          {'title': '討伐', 'memo': 'memo'},
        ),
        isFalse,
      );
    });

    test('いずれか1項目でも変われば変更あり', () {
      expect(
        UnsavedChangesGuard.isAnyDirty(
          {'title': '討伐', 'memo': 'memo'},
          {'title': '討伐', 'memo': 'memo2'},
        ),
        isTrue,
      );
    });

    test('片方にしか無いキーは変更あり', () {
      expect(
        UnsavedChangesGuard.isAnyDirty({'title': '討伐'}, {'title': '討伐', 'memo': 'x'}),
        isTrue,
      );
    });
  });

  test('確認文言は破棄を明示する', () {
    expect(UnsavedChangesGuard.confirmMessage(), contains('破棄'));
  });
}
