import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/domain/settings_write_result.dart';

void main() {
  group('SettingsWriteResult', () {
    test('success は ok=true で理由を持たない', () {
      const result = SettingsWriteResult.success();
      expect(result.ok, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('failure は ok=false で理由を持つ', () {
      const result = SettingsWriteResult.failure('保存に失敗しました');
      expect(result.ok, isFalse);
      expect(result.errorMessage, '保存に失敗しました');
    });

    test('const 構築でき、同値なら等価', () {
      const a = SettingsWriteResult.failure('x');
      const b = SettingsWriteResult.failure('x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const SettingsWriteResult.success(), isFalse);
    });

    test('toString は失敗理由を含む', () {
      expect(const SettingsWriteResult.success().toString(), contains('ok'));
      expect(
        const SettingsWriteResult.failure('だめ').toString(),
        contains('だめ'),
      );
    });
  });
}
