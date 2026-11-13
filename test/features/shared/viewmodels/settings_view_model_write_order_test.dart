import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';

/// 保存の成否・完了タイミングを試練から操作できるフェイク。
///
/// 既存シグネチャ `Future<void> setXxx(...)` を override するので、
/// ViewModel → writeXxx → 仮想ディスパッチ → この override、の経路を通る。
class _ControllableRepo extends SettingsRepository {
  bool failSfx = false;
  bool failTheme = false;
  bool failBackup = false;
  bool failDebug = false;

  /// 非 null の間は setThemeMode が完了しない（保存順序の観測用）。
  Completer<void>? themeGate;

  int sfxWriteCount = 0;
  double? lastWrittenVolume;

  @override
  Future<void> setSfxVolume(double volume) async {
    lastWrittenVolume = volume;
    if (failSfx) throw StateError('sfx volume save failed');
  }

  @override
  Future<void> setSfxEnabled(bool enabled) async {
    sfxWriteCount++;
    if (failSfx) throw StateError('sfx save failed');
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) {
    final gate = themeGate;
    if (gate != null) {
      return gate.future.then((_) {
        if (failTheme) throw StateError('theme save failed');
      });
    }
    return failTheme
        ? Future<void>.error(StateError('theme save failed'))
        : Future<void>.value();
  }

  @override
  Future<void> setLastBackupTime(DateTime time) async {
    if (failBackup) throw StateError('backup save failed');
  }

  @override
  Future<void> setDebugModeEnabled(bool enabled) async {
    if (failDebug) throw StateError('debug save failed');
  }
}

void main() {
  late _ControllableRepo repo;
  late SettingsViewModel vm;
  late int notifyCount;

  setUp(() {
    repo = _ControllableRepo();
    vm = SettingsViewModel(repo);
    notifyCount = 0;
    vm.addListener(() => notifyCount++);
  });

  test('① 保存失敗でメモリは旧値のまま・lastWriteError 非null・通知1回', () async {
    repo.failSfx = true;

    await vm.setSfxEnabled(false);

    expect(vm.isSfxEnabled, isTrue);
    expect(vm.lastWriteError, isNotNull);
    expect(vm.lastWriteError!.isNotEmpty, isTrue);
    expect(notifyCount, 1);
  });

  test('② 保存が完了する前は getter が旧値（順序の不変条件）', () async {
    final gate = Completer<void>();
    repo.themeGate = gate;

    final pending = vm.setThemeMode(ThemeMode.light);

    // 保存未完了の時点では新値を返さない
    expect(vm.themeMode, ThemeMode.dark);
    expect(vm.lastWriteError, isNull);

    gate.complete();
    await pending;

    expect(vm.themeMode, ThemeMode.light);
  });

  test('②-2 保存が完了する前は通知もしない', () async {
    final gate = Completer<void>();
    repo.themeGate = gate;

    final pending = vm.setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(notifyCount, 0);

    gate.complete();
    await pending;
    expect(notifyCount, 1);
  });

  test('③ 成功でメモリ確定・lastWriteError は null', () async {
    await vm.setSfxEnabled(false);

    expect(vm.isSfxEnabled, isFalse);
    expect(vm.lastWriteError, isNull);
    expect(repo.sfxWriteCount, 1);
  });

  test('④ 失敗の後の成功で lastWriteError が消える', () async {
    repo.failSfx = true;
    await vm.setSfxEnabled(false);
    expect(vm.lastWriteError, isNotNull);

    repo.failSfx = false;
    await vm.setSfxEnabled(false);

    expect(vm.isSfxEnabled, isFalse);
    expect(vm.lastWriteError, isNull);
  });

  test('⑤ recordBackupNow は保存失敗でも時刻を反映し理由を載せる', () async {
    repo.failBackup = true;

    await vm.recordBackupNow();

    expect(vm.lastBackupTime, isNotNull);
    expect(vm.lastWriteError, isNotNull);
    expect(vm.lastWriteError, contains('バックアップ'));
  });

  test('⑤-2 recordBackupNow 成功なら理由は null', () async {
    await vm.recordBackupNow();

    expect(vm.lastBackupTime, isNotNull);
    expect(vm.lastWriteError, isNull);
  });

  test('tryEnableDebugMode は同期で true を返し、保存失敗は zone へ漏れない', () async {
    repo.failDebug = true;

    final ok = vm.tryEnableDebugMode('11111111');
    expect(ok, isTrue);
    expect(vm.isDebugMode, isTrue);

    await Future<void>.delayed(Duration.zero);
    expect(vm.lastWriteError, isNotNull);
  });

  test('tryEnableDebugMode 成功で lastWriteError は null のまま', () async {
    expect(vm.tryEnableDebugMode('11111111'), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(vm.lastWriteError, isNull);
  });

  test('音量はクランプして保存する（成功経路）', () async {
    await vm.setSfxVolume(5.0);

    expect(vm.sfxVolume, 1.0);
    expect(repo.lastWrittenVolume, 1.0);
    expect(vm.lastWriteError, isNull);
  });

  test('音量はクランプ後の値で保存され、失敗時は旧値のまま', () async {
    repo.failSfx = true;
    final before = vm.sfxVolume;

    await vm.setSfxVolume(5.0);

    expect(vm.sfxVolume, before);
    expect(vm.lastWriteError, isNotNull);
  });
}
