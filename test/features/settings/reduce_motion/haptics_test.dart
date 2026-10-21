import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/haptics.dart';

void main() {
  testWidgets('hapticTap はプラットフォームチャネル未解決でも例外を投げない',
      (tester) async {
    expect(() => hapticTap(), returnsNormally);
  });

  testWidgets('hapticTap を連続で呼んでも同期的に返る（await しない）',
      (tester) async {
    for (var i = 0; i < 3; i++) {
      expect(() => hapticTap(), returnsNormally);
    }
    // 保留 Future を待たずにフレームが進むこと（永久未完了なら固まる）
    await tester.pump();
  });
}
