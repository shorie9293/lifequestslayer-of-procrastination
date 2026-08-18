import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/core/utils/feature_flag_service.dart';
import 'package:rpg_todo/core/utils/feature_flags.dart';

void main() {
  group('FeatureFlag 定義', () {
    test('未完成機能（experimentalBattleV2）は既定で無効', () {
      expect(FeatureFlag.experimentalBattleV2.defaultEnabled, false);
    });

    test('フラグの key は一意（A/Bテストの混在を安全にする）', () {
      final keys = FeatureFlag.values.map((f) => f.key).toSet();
      expect(keys.length, FeatureFlag.values.length);
    });

    test('FeatureFlags ファサードは enum 値へアクセスできる', () {
      expect(FeatureFlags.experimentalBattleV2,
          FeatureFlag.experimentalBattleV2);
      expect(FeatureFlags.skillTree, FeatureFlag.skillTree);
    });

    test('全フラグが人間可読な説明を持つ', () {
      for (final flag in FeatureFlag.values) {
        expect(flag.description, isNotEmpty);
      }
    });
  });

  group('FeatureFlagService - 有効/無効判定・永続化', () {
    late FeatureFlagService service;
    late String hivePath;

    setUp(() async {
      hivePath =
          '${Directory.systemTemp.path}/hive_test_feature_flags_${DateTime.now().millisecondsSinceEpoch}';
      Hive.init(hivePath);
      service = FeatureFlagService();
    });

    tearDown(() async {
      await Hive.close();
      final dir = Directory(hivePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('オーバーライド無しではコンパイル時デフォルトを返す', () async {
      expect(await service.isEnabled(FeatureFlag.experimentalBattleV2), false);
      // デフォルト true の既存機能フラグ
      expect(await service.isEnabled(FeatureFlag.battleSceneV2), true);
    });

    test('setEnabled で有効化すると永続化され別インスタンスでも維持される', () async {
      await service.setEnabled(FeatureFlag.experimentalBattleV2, true);
      expect(await service.isEnabled(FeatureFlag.experimentalBattleV2), true);

      // 再起動相当（新インスタンス）でも Hive から復元される
      final service2 = FeatureFlagService();
      expect(await service2.isEnabled(FeatureFlag.experimentalBattleV2), true);
    });

    test('setEnabled で無効化できる', () async {
      await service.setEnabled(FeatureFlag.battleSceneV2, false);
      expect(await service.isEnabled(FeatureFlag.battleSceneV2), false);
    });

    test('reset はオーバーライドを破棄しデフォルトへ戻す', () async {
      await service.setEnabled(FeatureFlag.experimentalBattleV2, true);
      await service.reset(FeatureFlag.experimentalBattleV2);
      expect(await service.isEnabled(FeatureFlag.experimentalBattleV2), false);
    });

    test('resetAll は全フラグをデフォルトへ戻す', () async {
      await service.setEnabled(FeatureFlag.experimentalBattleV2, true);
      await service.setEnabled(FeatureFlag.skillTree, true);
      await service.resetAll();
      expect(await service.isEnabled(FeatureFlag.experimentalBattleV2), false);
      expect(await service.isEnabled(FeatureFlag.skillTree), false);
    });

    test('フラグ同士は独立（A/Bテスト基盤）', () async {
      await service.setEnabled(FeatureFlag.experimentalBattleV2, true);
      expect(await service.isEnabled(FeatureFlag.skillTree), false);
      expect(await service.isEnabled(FeatureFlag.experimentalBattleV2), true);
    });

    test('isEnabledSync は非同期を介さず現在値を返す', () async {
      expect(service.isEnabledSync(FeatureFlag.experimentalBattleV2), false);
      await service.setEnabled(FeatureFlag.experimentalBattleV2, true);
      expect(service.isEnabledSync(FeatureFlag.experimentalBattleV2), true);
    });
  });
}
