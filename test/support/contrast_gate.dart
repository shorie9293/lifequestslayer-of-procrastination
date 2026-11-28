// ライト／ダーク実描画コントラスト走査の正準ゲート（共有実装）。
//
// これまで 43 本の *_light_contrast_test.dart が各々コピペしていた
//   ・文字色/背景色のコントラスト比算出（_contrast）
//   ・祖先塗りの合成による実効背景の解決（_effectiveBackground）
//   ・走査対象判定（_measurable）と走査結果（_Scan / _scan）
//   ・3.0:1 判定と母数下限・ダーク墨色漏れのアサート
//   ・標準 DI モック（Player/Task/Settings リポジトリ）
// をここ一箇所へ集約する。個々の試練ファイルは「対象画面・母数下限・期待」の
// 宣言だけを持ち、判定ロジックは一切複製しない。
//
// 画面ごとに僅かに異なっていた走査方言（グラデーションの代表色・走査対象の
// 拡張・並行作業中画面の除外）は [ScanConfig] で表現する。実装は常に 1 つ。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';

/// 判定しきい値（3.0:1）。負の対照でここを上げると赤化する。
const double kMinContrastRatio = 3.0;

/// 標準の走査対象パターン（数字・ラテン・ひらがな・カタカナ・漢字）。
const String kStdMeasurablePattern = r'[0-9A-Za-z\u3040-\u30FF\u4E00-\u9FFF]';

/// 戦闘画面などの拡張パターン（句読点・全角記号も数える）。
const String kExtendedMeasurablePattern =
    r'[0-9A-Za-z\u3040-\u30FF\u4E00-\u9FFF\u3001-\u303F\uFF01-\uFF60]';

/// ライト専用の墨色。ダークでこれらが漏れたら退行とみなす。
const List<int> kLightInkColors = <int>[
  0xFF2B2B2B,
  0xFF4A4A4A,
  0xFF5A5A5A,
  0xFF6B6B6B,
];

/// グラデーション背景を代表させる色の選び方。
enum GradientMode {
  /// 最も暗い停止色（白文字＝高コントラスト側に倒さない保守側）。
  darkest,

  /// 最初の停止色（戦闘演出の暗幕近似）。
  first,

  /// グラデーションを無視し d.color のみを見る（旧・町など）。
  none,
}

/// 画面ごとに異なる走査方言の設定。実装は 1 つのまま、ここだけ差し替える。
class ScanConfig {
  const ScanConfig({
    this.measurablePattern = kStdMeasurablePattern,
    this.gradientMode = GradientMode.darkest,
    this.includeRawChip = true,
    this.includeColoredBox = true,
    this.includeMaterial = true,
    this.foreignTypes = const <String>{},
  });

  final String measurablePattern;
  final GradientMode gradientMode;
  final bool includeRawChip;
  final bool includeColoredBox;
  final bool includeMaterial;

  /// 「並行作業中で本担当の対象外」として走査から除外し件数だけ数える画面型名。
  final Set<String> foreignTypes;

  RegExp get measurable => RegExp(measurablePattern);

  /// 旧・町など「色リテラルのみ（グラデ・Chip を見ない）」方言。
  static const classic = ScanConfig(
    gradientMode: GradientMode.none,
    includeRawChip: false,
  );

  /// グラデーションを最も暗い停止色で代表させる方言（大多数）。
  static const gradient = ScanConfig(
    gradientMode: GradientMode.darkest,
    includeRawChip: false,
  );

  /// グラデーション＋Chip 背景まで見る方言（メイン画面等）。
  static const gradientChip = ScanConfig(gradientMode: GradientMode.darkest);

  /// 戦闘系：グラデ先頭色・拡張走査対象・装飾ボックスのみ（Material/ColoredBox 無視）。
  static const battle = ScanConfig(
    measurablePattern: kExtendedMeasurablePattern,
    gradientMode: GradientMode.first,
    includeRawChip: false,
    includeColoredBox: false,
    includeMaterial: false,
  );
}

/// WCAG 相対輝度に基づくコントラスト比。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _darkestOf(List<Color> colors) =>
    colors.reduce((a, b) => a.computeLuminance() <= b.computeLuminance() ? a : b);

/// 祖先の塗り（BoxDecoration・グラデーション・ColoredBox・Material・Chip）を
/// 外側から合成し、文字が実際に載っている実効背景色を求める。
Color effectiveBackground(
  Element element,
  Color scaffoldColor, {
  GradientMode gradientMode = GradientMode.darkest,
  bool includeRawChip = true,
  bool includeColoredBox = true,
  bool includeMaterial = true,
}) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox) {
      final d = widget.decoration;
      if (d is BoxDecoration) {
        if (d.gradient != null && d.gradient!.colors.isNotEmpty) {
          if (gradientMode == GradientMode.darkest) {
            layers.add(_darkestOf(d.gradient!.colors));
          } else if (gradientMode == GradientMode.first) {
            layers.add(d.gradient!.colors.first);
          } else if (d.color != null) {
            layers.add(d.color!);
          }
        } else if (d.color != null) {
          layers.add(d.color!);
        }
      }
    } else if (widget is ColoredBox && includeColoredBox) {
      layers.add(widget.color);
    } else if (widget is Material && widget.color != null && includeMaterial) {
      layers.add(widget.color!);
    } else if (widget is RawChip && includeRawChip) {
      // Chip の背景は Material.color ではなく _RenderChip.paint が描くため拾う。
      // 選択中のチップは backgroundColor ではなく selectedColor が塗られる
      // （SDK chip.dart の _IndividualOverrides.resolve）。選択状態を尊重する。
      final chipColor = widget.selected && widget.selectedColor != null
          ? widget.selectedColor
          : widget.backgroundColor;
      if (chipColor != null) layers.add(chipColor);
    }
    return true;
  });
  var bg = scaffoldColor;
  for (final layer in layers.reversed) {
    bg = Color.alphaBlend(layer, bg);
  }
  return bg;
}

/// 数字・ラテン・かな・漢字（＋設定時は句読点）を含む文字列だけを走査対象とする。
bool isMeasurable(String text, [ScanConfig config = const ScanConfig()]) =>
    config.measurable.hasMatch(text);

/// 1 回の実描画走査結果。
class ContrastScan {
  int measurable = 0;
  int violations = 0;
  int foreign = 0;
  double minRatio = 99;
  String worst = '';
  final Set<int> colors = <int>{};
  final List<String> details = <String>[];

  @override
  String toString() => 'measurable=$measurable violations=$violations '
      '${foreign > 0 ? 'foreign=$foreign ' : ''}'
      'min=${minRatio.toStringAsFixed(2)}:1 ($worst)'
      '${details.isEmpty ? '' : ' -> $details'}';
}

bool _inForeignSubtree(Element element, Set<String> types) {
  if (types.isEmpty) return false;
  var foreign = false;
  element.visitAncestorElements((ancestor) {
    if (types.contains(ancestor.widget.runtimeType.toString())) {
      foreign = true;
      return false;
    }
    return true;
  });
  return foreign;
}

/// 描画木を走査し、文字色と実効背景のコントラストを 3.0:1 で判定する。
ContrastScan scanContrast(
  WidgetTester tester, {
  ScanConfig config = const ScanConfig(),
}) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final scaffold = app.theme!.scaffoldBackgroundColor;
  final fallback = app.theme!.textTheme.bodyMedium?.color ?? Colors.black;
  final scan = ContrastScan();
  final counted = <String>{};
  for (final element in tester.allElements) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph) continue;
    if (ro.debugNeedsLayout) continue;
    final plain = ro.text.toPlainText();
    if (!isMeasurable(plain, config)) continue;
    if (_inForeignSubtree(element, config.foreignTypes)) {
      scan.foreign++;
      continue;
    }
    final bg = effectiveBackground(element, scaffold,
        gradientMode: config.gradientMode,
        includeRawChip: config.includeRawChip,
        includeColoredBox: config.includeColoredBox,
        includeMaterial: config.includeMaterial);
    final raw = ro.text.style?.color ?? fallback;
    final eff = Color.alphaBlend(raw, bg);
    final ratio = contrastRatio(eff, bg);
    scan.measurable++;
    scan.colors.add(raw.toARGB32());
    if (ratio < scan.minRatio) {
      scan.minRatio = ratio;
      scan.worst = '"$plain"';
    }
    if (ratio < kMinContrastRatio && counted.add(plain)) {
      scan.violations++;
      scan.details.add('"$plain"=${ratio.toStringAsFixed(2)}:1 '
          'fg=${raw.toARGB32().toRadixString(16)} '
          'bg=${bg.toARGB32().toRadixString(16)}');
    }
  }
  return scan;
}

/// ライトテーマの門：母数下限を満たし、3.0:1 未満が 0 件であること。
void expectLightContrast(
  ContrastScan scan, {
  required int minMeasurable,
  required String label,
}) {
  // ignore: avoid_print
  print('$label LIGHT $scan');
  expect(scan.measurable, greaterThanOrEqualTo(minMeasurable),
      reason: '$label: 走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
  expect(scan.violations, 0, reason: '$label: ライトで読めない文字: $scan');
}

/// ダークテーマの門：3.0:1 未満が 0 件、母数下限を満たし、ライト専用の墨色が
/// 漏れていないこと（白系文字からの退行が無いこと）。
void expectDarkContrast(
  ContrastScan scan, {
  required int minMeasurable,
  required String label,
}) {
  // ignore: avoid_print
  print('$label DARK $scan');
  expect(scan.measurable, greaterThanOrEqualTo(minMeasurable),
      reason: '$label: 走査母数が少なすぎる＝空振りで緑になっている疑い: $scan');
  expect(scan.violations, 0, reason: '$label: ダークで読めない文字: $scan');
  for (final argb in kLightInkColors) {
    expect(scan.colors.contains(argb), isFalse,
        reason: '$label: ダークにライト専用の墨色 ${argb.toRadixString(16)} が漏れている');
  }
}

// ── 標準 DI モック（各試練ファイルへ複製しない） ──────────────

/// IPlayerRepository の標準フェイク。player をそのまま返す。
class StdPlayerRepository implements IPlayerRepository {
  StdPlayerRepository([Player? player]) : _player = player ?? Player();
  final Player _player;

  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

/// ITaskRepository の標準フェイク。tasks を返す（既定は空）。
class StdTaskRepository implements ITaskRepository {
  StdTaskRepository([List<Task>? tasks]) : _tasks = tasks ?? <Task>[];
  final List<Task> _tasks;

  @override
  Future<List<Task>> loadTasks() async => _tasks;
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

/// SettingsRepository の標準フェイク。画面ごとに必要な値だけ差し替える。
class StdSettingsRepository extends SettingsRepository {
  StdSettingsRepository({
    this.fontSizeScale = 1.0,
    this.knowledgeQuestEnabled = true,
    this.tutorialStep = 0,
    this.hasSeenConcept = false,
    this.tutorialChoiceMade = false,
    this.jobTutorialCompleted = false,
    this.sfxEnabled = false,
    this.battleSceneEnabled = false,
    this.debugModeEnabled = false,
  });

  final double fontSizeScale;
  final bool knowledgeQuestEnabled;
  final int tutorialStep;
  final bool hasSeenConcept;
  final bool tutorialChoiceMade;
  final bool jobTutorialCompleted;
  final bool sfxEnabled;
  final bool battleSceneEnabled;
  final bool debugModeEnabled;

  @override
  Future<double> getFontSizeScale() async => fontSizeScale;
  @override
  Future<void> setFontSizeScale(double scale) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => knowledgeQuestEnabled;
  @override
  Future<void> setKnowledgeQuestEnabled(bool enabled) async {}
  @override
  Future<void> saveFatiguePopupDate(DateTime date) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<int> getTutorialStep() async => tutorialStep;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => hasSeenConcept;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool value) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => tutorialChoiceMade;
  @override
  Future<void> setTutorialChoiceMade(bool value) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => jobTutorialCompleted;
  @override
  Future<void> setJobTutorialCompleted(bool value) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => debugModeEnabled;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => sfxEnabled;
  @override
  Future<double> getSfxVolume() async => 0.7;
  @override
  Future<void> setSfxVolume(double volume) async {}
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => battleSceneEnabled;
  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}

  /// ViewModel の初期ロード待ち（GameViewModel 等）で使う共通タイマ。
  static Future<void> waitUntilLoaded(
    bool Function() isLoaded, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final start = DateTime.now();
    while (!isLoaded()) {
      if (DateTime.now().difference(start) > timeout) {
        throw Exception('ViewModel のロードがタイムアウトしました');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}