// 親探針（イシコリドメ）: 眷属の報告を鵜呑みにせず、合成の不変条件を独立に撃つ。
//
// P1 実Hive往復: VM → 実リポジトリ → settingsBox に永続化され、別VMの load() で復元される
// P2 失敗注入: メモリは旧値のまま・lastWriteError 非null・notifyListeners 発火
// P3 順序: 保存が完了する前は getter が旧値（メモリ先行更新の不在）
// P4 失敗時の appLog.warn がちょうど1回
// P5 仮想ディスパッチ互換: writeXxx は既存フェイクの void setter override を通る
// P6 7 setter は例外を握り潰さず伝播する（catch (_) {} の全廃）
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 既存試練のフェイクと同じ流儀（void setter を override する）。
class _CountingSettingsRepo extends SettingsRepository {
  _CountingSettingsRepo({super.logger});

  int themeWrites = 0;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    themeWrites++;
  }
}

/// 保存が必ず失敗するフェイク。
class _FailingSettingsRepo extends SettingsRepository {
  _FailingSettingsRepo({super.logger});

  @override
  Future<void> setSfxEnabled(bool enabled) async =>
      throw StateError('sfx save failed');

  @override
  Future<void> setThemeMode(ThemeMode mode) async =>
      throw StateError('theme save failed');
}

/// 保存が完了しないフェイク（順序の不変条件を撃つ）。
class _PendingSettingsRepo extends SettingsRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await gate.future;
  }
}

void main() {
  group('親探針 P1 実Hive往復', () {
    late String hivePath;

    setUp(() async {
      hivePath =
          '${Directory.systemTemp.path}/hive_probe_${DateTime.now().microsecondsSinceEpoch}';
      Hive.init(hivePath);
    });

    tearDown(() async {
      await Hive.close();
      final dir = Directory(hivePath);
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('VMで設定したテーマが box に永続化され、別VMの load で復元される', () async {
      final vm = SettingsViewModel(SettingsRepository());
      await vm.setThemeMode(ThemeMode.light);
      expect(vm.lastWriteError, isNull);

      final box = await Hive.openBox('settingsBox');
      expect(box.get('themeMode'), 'light');

      final restored = SettingsViewModel(SettingsRepository());
      await restored.load();
      expect(restored.themeMode, ThemeMode.light);
    });
  });

  group('親探針 P2-P4 失敗の可視化', () {
    test('P2 失敗時はメモリが旧値のまま・理由が載り・通知は走る', () async {
      final vm = SettingsViewModel(_FailingSettingsRepo());
      var notified = 0;
      vm.addListener(() => notified++);

      expect(vm.isSfxEnabled, isTrue);
      await vm.setSfxEnabled(false);

      expect(vm.isSfxEnabled, isTrue, reason: '失敗したのに成功したように見えてはならない');
      expect(vm.lastWriteError, isNotNull);
      expect(notified, 1);
    });

    test('P3 保存が完了する前は getter が旧値', () async {
      final repo = _PendingSettingsRepo();
      final vm = SettingsViewModel(repo);

      final pending = vm.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(vm.themeMode, ThemeMode.dark, reason: 'メモリ先行更新が残っている');

      repo.gate.complete();
      await pending;
      expect(vm.themeMode, ThemeMode.light);
    });

    test('P4 失敗時の warn はちょうど1回・成功時は出ない', () async {
      final logs = <String>[];
      final repo = _FailingSettingsRepo(
        logger: AppLogger(isDebug: true, sink: logs.add),
      );

      await repo.writeSfxEnabled(false);
      final warns = logs.where((l) => l.startsWith('[WARN]')).toList();
      expect(warns.length, 1);

      final okLogs = <String>[];
      final okRepo = _CountingSettingsRepo(
        logger: AppLogger(isDebug: true, sink: okLogs.add),
      );
      final result = await okRepo.writeThemeMode(ThemeMode.light);
      expect(result.ok, isTrue);
      expect(okLogs.where((l) => l.startsWith('[WARN]')), isEmpty);
    });
  });

  group('親探針 P5 仮想ディスパッチ互換', () {
    test('writeXxx は既存フェイクの void setter override を通る（本番実装へ落ちない）', () async {
      final repo = _CountingSettingsRepo();
      final result = await repo.writeThemeMode(ThemeMode.light);
      expect(result.ok, isTrue);
      expect(repo.themeWrites, 1);
    });
  });

  group('親探針 P6 例外の伝播', () {
    late String source;

    setUp(() async {
      source = await File(
        'lib/features/shared/data/settings_repository.dart',
      ).readAsString();
    });

    test('ソース上に無音の catch (_) {} が残っていない', () {
      expect(source.contains('catch (_) {}'), isFalse);
    });

    test('7 setter の本体に try/catch が無い（例外が呼出元へ伝播する）', () {
      const setters = [
        'setDebugModeEnabled',
        'setGriffonEnabled',
        'setSfxEnabled',
        'setSfxVolume',
        'setBattleSceneEnabled',
        'setThemeMode',
        'setLastBackupTime',
      ];
      for (final name in setters) {
        final start = source.indexOf('Future<void> $name(');
        expect(start, greaterThan(-1), reason: '$name が見つからない');
        // 本体は次の "Future<" 宣言の直前まで（このリポジトリの setter は連続して並ぶ）
        final rest = source.substring(start + 1);
        final nextDecl = rest.indexOf('  Future<');
        final body = nextDecl == -1 ? rest : rest.substring(0, nextDecl);
        expect(body.contains('try {'), isFalse, reason: '$name が try を持つ');
        expect(body.contains('catch'), isFalse, reason: '$name が catch を持つ');
      }
    });
  });
}
