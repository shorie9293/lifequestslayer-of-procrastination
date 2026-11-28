// 画面台帳（screen_ledger.dart）の各ケースを 1 つの testWidgets として走査する。
//
// 個々の *_light_contrast_test.dart は台帳キーを呼ぶだけ。画面を台帳へ 1 件足せば、
// 一括走査門（all_screens_contrast_gate_test.dart）が自動的に拾う。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';

import 'contrast_case.dart';
import 'contrast_gate.dart';
import 'screen_ledger.dart';
import 'test_viewport.dart';

/// 台帳の全ケースを走査する（一括走査門が呼ぶ）。
void runAllScreenCases() {
  for (final c in screenLedger) {
    _runCase(c);
  }
}

/// 台帳の指定キーだけを走査する（個別画面ファイルが呼ぶ）。
void runScreenFromLedger(String key) {
  _runCase(screenLedgerByKey(key));
}

void _runCase(ContrastCase c) {
  final themeLabel = c.dark ? 'ダーク' : 'ライト';
  testWidgets('${c.label}: $themeLabel実描画で 3.0:1 未満が 0 件', (tester) async {
    useRealDeviceViewport(tester, widthDp: c.widthDp, heightDp: c.heightDp);
    if (c.needsHive) {
      final dir = Directory.systemTemp.createTempSync('contrast_hive_');
      Hive.init(dir.path);
      addTearDown(() async {
        await Hive.close();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    }
    c.warmUp?.call();
    final theme = c.dark
        ? GameThemes.forJob(Job.adventurer)
        : GameThemes.lightForJob(Job.adventurer);
    await c.pump(tester, theme);
    if (c.interact != null) await c.interact!(tester);
    final scan = scanContrast(tester, config: c.config);
    if (c.dark) {
      // ignore: avoid_print
      print('${c.tag} DARK $scan');
      expect(scan.measurable, greaterThanOrEqualTo(c.minMeasurable),
          reason: '${c.tag}: 走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
      if (c.darkViolationCheck) {
        expect(scan.violations, 0,
            reason: '${c.tag}: ダークで読めない文字: $scan');
      }
      if (c.darkInkCheck) {
        for (final argb in kLightInkColors) {
          expect(scan.colors.contains(argb), isFalse,
              reason: '${c.tag}: ダークにライト専用の墨色 '
                  '${argb.toRadixString(16)} が漏れている');
        }
      }
      if (c.expectWhiteColor) {
        expect(scan.colors, contains(0xFFFFFFFF),
            reason: '${c.tag}: ダークの白系文字が失われている: $scan');
      }
    } else {
      expectLightContrast(scan,
          minMeasurable: c.minMeasurable, label: c.tag);
      if (c.expectForeign) {
        expect(scan.foreign, greaterThan(0),
            reason: '${c.tag}: foreign 除外が効いていない＝走査自体が壊れている疑い: $scan');
      }
    }
  });
}