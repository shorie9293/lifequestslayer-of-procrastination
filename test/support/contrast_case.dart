// コントラスト走査の「1 試練 = 1 ケース」モデル。
//
// 画面台帳（screen_ledger.dart）がこの ContrastCase の一覧を持ち、
// 走査ランナ（contrast_runner.dart）が各ケースを 1 つの testWidgets として実行する。
// 個々の画面ファイルは台帳キーを 1 つ呼ぶだけの薄い宣言になる。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_gate.dart';
import 'test_viewport.dart';

/// 画面を pump する関数（ライト/ダークいずれの ThemeData も受け取る）。
typedef ContrastPump = Future<void> Function(
    WidgetTester tester, ThemeData theme);

/// 1 ケース = 1 つの実描画走査。ライト/ダークは [dark] で区別する。
class ContrastCase {
  const ContrastCase({
    required this.key,
    required this.label,
    required this.tag,
    required this.dark,
    required this.minMeasurable,
    required this.pump,
    this.interact,
    this.config = const ScanConfig(),
    this.widthDp = kDeviceWidthDp,
    this.heightDp = kDeviceHeightDp,
    this.darkInkCheck = true,
    this.darkViolationCheck = true,
    this.expectForeign = false,
    this.expectWhiteColor = false,
    this.needsHive = false,
    this.warmUp,
  });

  /// 台帳内で一意なキー（例 "town_light" / "town_dark"）。
  final String key;

  /// testWidgets の説明的名前の接頭辞。
  final String label;

  /// 走査ログのタグ（例 "TOWN"）。
  final String tag;

  /// true ならダークテーマ門、false ならライトテーマ門。
  final bool dark;

  /// 走査母数（measurable）の下限。空振り緑を排除する。
  final int minMeasurable;

  /// 画面を pump する。
  final ContrastPump pump;

  /// pump 後・scan 前に実行する追加操作（ダイアログを開くタップ等）。
  final Future<void> Function(WidgetTester tester)? interact;

  /// 画面方言（グラデ代表色・Chip・走査対象・除外画面）。
  final ScanConfig config;

  final double widthDp;
  final double heightDp;

  /// ダーク門でライト専用墨色の漏れを検査するか。
  final bool darkInkCheck;

  /// ダーク門で 3.0:1 未満 0 件を検査するか（一部画面は装飾チップ上の白文字を許容し検査しない）。
  final bool darkViolationCheck;

  /// ライト門で foreign（対象外画面）除外が実際に効いているか検査するか。
  final bool expectForeign;

  /// ダーク門で白系文字（0xFFFFFFFF）が実在すること（墨色への退行が無いこと）を検査するか。
  final bool expectWhiteColor;

  /// Hive を一時ディレクトリで初期化してから pump するか（町系画面）。
  final bool needsHive;

  /// pump 前に走らせる同期の下ごしらえ（getIt 登録等）。テストごとに呼ばれる。
  final void Function()? warmUp;
}