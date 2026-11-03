import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 本番ログ垂れ流しの静的ゲート。
///
/// `lib/` 配下の `.dart` に残る raw な `print(` / `debugPrint(` の総数を数え、
/// `tool/print_baseline.txt` の上限を超えたら失敗する。
/// 新規に raw print を足すと赤くなるので、必ず `appLog`（core/logging）を使うこと。
void main() {
  test('lib 配下の raw print が baseline を超えない', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ が見つからない（リポジトリ根で実行せよ）');

    final pattern = RegExp(r'\b(debugPrint|print)\s*\(');
    final perFile = <String, int>{};
    var total = 0;

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final hits = pattern.allMatches(entity.readAsStringSync()).length;
      if (hits == 0) continue;
      perFile[entity.path] = hits;
      total += hits;
    }

    final baselineFile = File('tool/print_baseline.txt');
    expect(baselineFile.existsSync(), isTrue,
        reason: 'tool/print_baseline.txt が無い（移行後の件数を1行で置くこと）');
    final baseline = int.parse(baselineFile.readAsStringSync().trim());

    final breakdown = (perFile.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');

    expect(
      total,
      lessThanOrEqualTo(baseline),
      reason: 'raw print が baseline を超過: 実測=$total baseline=$baseline\n$breakdown',
    );
  });
}
