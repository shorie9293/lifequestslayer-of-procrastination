import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/settings_write_result.dart';

/// 保存が必ず失敗するテストダブル（void setter を override して throw する）。
/// 既存シグネチャ `Future<void> setXxx(...)` は不変なので、
/// writeXxx は仮想ディスパッチでこの override を必ず通る。
class _FailingSettingsRepo extends SettingsRepository {
  _FailingSettingsRepo({super.logger});

  @override
  Future<void> setDebugModeEnabled(bool enabled) async {
    throw StateError('debug save failed');
  }

  @override
  Future<void> setGriffonEnabled(bool enabled) async {
    throw StateError('griffon save failed');
  }

  @override
  Future<void> setSfxEnabled(bool enabled) async {
    throw StateError('sfx save failed');
  }

  @override
  Future<void> setSfxVolume(double volume) async {
    throw StateError('sfx volume save failed');
  }

  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {
    throw StateError('battle scene save failed');
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    throw StateError('theme save failed');
  }

  @override
  Future<void> setLastBackupTime(DateTime time) async {
    throw StateError('backup time save failed');
  }

  @override
  Future<void> setFontSizeScale(double scale) async {
    throw StateError('font size save failed');
  }

  @override
  Future<void> setKnowledgeQuestEnabled(bool enabled) async {
    throw StateError('knowledge quest save failed');
  }

  @override
  Future<void> setMorningNotificationEnabled(bool enabled) async {
    throw StateError('morning notification save failed');
  }
}

void main() {
  group('SettingsRepository.writeXxx - 失敗は結果型で返る', () {
    late List<String> logs;
    late _FailingSettingsRepo repo;

    setUp(() {
      logs = <String>[];
      repo = _FailingSettingsRepo(
        logger: AppLogger(isDebug: false, sink: logs.add),
      );
    });

    test('setter の例外は外へ出ず、writeSfxEnabled が ok=false を返す', () async {
      final result = await repo.writeSfxEnabled(false);

      expect(result.ok, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage!.isNotEmpty, isTrue);
    });

    test('7つの結果型ラッパー全てが失敗を返し、例外を投げない', () async {
      final results = <SettingsWriteResult>[
        await repo.writeDebugModeEnabled(true),
        await repo.writeGriffonEnabled(true),
        await repo.writeSfxEnabled(false),
        await repo.writeSfxVolume(0.4),
        await repo.writeBattleSceneEnabled(false),
        await repo.writeThemeMode(ThemeMode.light),
        await repo.writeLastBackupTime(DateTime(2026, 1, 1)),
      ];

      expect(results, hasLength(7));
      for (final r in results) {
        expect(r.ok, isFalse);
        expect(r.errorMessage, isNotNull);
        expect(r.errorMessage!.isNotEmpty, isTrue);
      }
    });

    test('ViewModel 順序用の3ラッパーも失敗を返す', () async {
      expect((await repo.writeFontSizeScale(1.0)).ok, isFalse);
      expect((await repo.writeKnowledgeQuestEnabled(false)).ok, isFalse);
      expect((await repo.writeMorningNotificationEnabled(false)).ok, isFalse);
    });

    test('失敗1回につき appLog.warn は1回だけ出る', () async {
      await repo.writeSfxEnabled(false);

      expect(logs, hasLength(1));
      expect(logs.single, startsWith('[WARN]'));
      expect(logs.single, contains('効果音設定'));
    });
  });

  group('SettingsRepository.writeXxx - 実Hive往復の成功経路', () {
    late String hivePath;
    late List<String> logs;
    late SettingsRepository repo;

    setUp(() async {
      hivePath = '${Directory.systemTemp.path}/hive_write_'
          '${DateTime.now().microsecondsSinceEpoch}';
      Hive.init(hivePath);
      logs = <String>[];
      repo = SettingsRepository(
        logger: AppLogger(isDebug: false, sink: logs.add),
      );
    });

    tearDown(() async {
      await Hive.close();
      final dir = Directory(hivePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('writeSfxEnabled 成功で ok=true・ログ無し・再読で反映', () async {
      final result = await repo.writeSfxEnabled(false);

      expect(result.ok, isTrue);
      expect(result.errorMessage, isNull);
      expect(logs, isEmpty);
      expect(await repo.getSfxEnabled(), isFalse);
    });

    test('writeThemeMode / writeLastBackupTime も往復する', () async {
      expect((await repo.writeThemeMode(ThemeMode.light)).ok, isTrue);
      expect(await repo.getThemeMode(), ThemeMode.light);

      final at = DateTime(2026, 5, 26, 12, 34);
      expect((await repo.writeLastBackupTime(at)).ok, isTrue);
      expect(await repo.getLastBackupTime(), at);
    });

    test('writeSfxVolume は 0.0〜1.0 にクランプして往復する', () async {
      expect((await repo.writeSfxVolume(2.0)).ok, isTrue);
      expect(await repo.getSfxVolume(), 1.0);
    });
  });
}
