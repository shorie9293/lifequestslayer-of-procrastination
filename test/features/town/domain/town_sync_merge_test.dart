import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/features/town/domain/town_sync_merge.dart';

void main() {
  group('decideTownSync', () {
    test('クラウドが上ならクラウドを採用する', () {
      final d = decideTownSync(
          localLevel: 1, localXp: 0, cloudLevel: 10, cloudXp: 98);
      expect(d.takeCloud, isTrue);
      expect(d.pushLocal, isFalse);
    });

    test('ローカルが上ならクラウドへ書き戻す', () {
      final d = decideTownSync(
          localLevel: 12, localXp: 5, cloudLevel: 10, cloudXp: 98);
      expect(d.takeCloud, isFalse);
      expect(d.pushLocal, isTrue);
    });

    test('同じレベルなら累積XPで比べる', () {
      expect(
        decideTownSync(
                localLevel: 5, localXp: 120, cloudLevel: 5, cloudXp: 40)
            .takeCloud,
        isFalse,
      );
      expect(
        decideTownSync(
                localLevel: 5, localXp: 40, cloudLevel: 5, cloudXp: 120)
            .takeCloud,
        isTrue,
      );
    });

    test('完全一致なら何もしない', () {
      final d = decideTownSync(
          localLevel: 10, localXp: 98, cloudLevel: 10, cloudXp: 98);
      expect(d.inSync, isTrue);
    });
  });

  group('shouldTakeCloudBuilding', () {
    test('クラウドの建物レベルが高い時だけ採用する', () {
      expect(shouldTakeCloudBuilding(localLevel: 2, cloudLevel: 3), isTrue);
      expect(shouldTakeCloudBuilding(localLevel: 3, cloudLevel: 3), isFalse);
      expect(shouldTakeCloudBuilding(localLevel: 4, cloudLevel: 3), isFalse);
    });
  });
}
