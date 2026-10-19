// 削除Undo（元に戻す）の純粋ドメイン試練。
//
// UndoBuffer は「一度だけ取り出す」ことで二重復元を構造的に防ぐ。
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/undo/domain/undo_buffer.dart';

void main() {
  group('UndoBuffer', () {
    test('初期状態は canUndo=false / take・peek は null', () {
      final buffer = UndoBuffer<String>();
      expect(buffer.canUndo, isFalse);
      expect(buffer.peek(), isNull);
      expect(buffer.take(), isNull);
    });

    test('push すると canUndo=true になり peek で中身が見える', () {
      final buffer = UndoBuffer<String>();
      buffer.push('クエストA');
      expect(buffer.canUndo, isTrue);
      expect(buffer.peek(), 'クエストA');
    });

    test('take は一度だけ値を返し、二度目は null（二重復元防止）', () {
      final buffer = UndoBuffer<String>();
      buffer.push('クエストA');
      expect(buffer.take(), 'クエストA');
      expect(buffer.take(), isNull);
      expect(buffer.canUndo, isFalse);
      expect(buffer.peek(), isNull);
    });

    test('peek は消費しない（何度でも同じ値・canUndo は true のまま）', () {
      final buffer = UndoBuffer<int>();
      buffer.push(42);
      expect(buffer.peek(), 42);
      expect(buffer.peek(), 42);
      expect(buffer.canUndo, isTrue);
      expect(buffer.take(), 42);
    });

    test('clear で破棄され take は null', () {
      final buffer = UndoBuffer<String>();
      buffer.push('クエストA');
      buffer.clear();
      expect(buffer.canUndo, isFalse);
      expect(buffer.take(), isNull);
    });

    test('push の連続は最新のみ保持し、押し出された旧値を返す', () {
      final buffer = UndoBuffer<String>();
      expect(buffer.push('first'), isNull);
      expect(buffer.push('second'), 'first');
      expect(buffer.peek(), 'second');
      expect(buffer.take(), 'second');
      expect(buffer.take(), isNull);
    });

    test('型違い: バッファは型ごとに独立で、型が保持される', () {
      final strings = UndoBuffer<String>();
      final numbers = UndoBuffer<int>();
      strings.push('text');
      numbers.push(7);

      expect(strings.peek(), isA<String>());
      expect(numbers.peek(), isA<int>());
      expect(strings.take(), 'text');
      // 別インスタンスの状態は共有されない
      expect(numbers.canUndo, isTrue);
      expect(numbers.take(), 7);

      final lists = UndoBuffer<List<String>>();
      lists.push(['a', 'b']);
      expect(lists.take(), ['a', 'b']);
    });
  });
}
