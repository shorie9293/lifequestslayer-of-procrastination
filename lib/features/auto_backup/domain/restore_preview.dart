import 'package:rpg_todo/domain/services/backup_registry.dart';
import 'package:rpg_todo/domain/services/backup_secret_keys.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';

/// 抜粋に出す上書き対象キーの既定件数。
const int kRestorePreviewSampleLimit = 5;

/// 復元前プレビュー（内訳＋上書き対象キーの抜粋＋文言）。
///
/// rpg-task の復元は [FullBackupService.decode] → `BackupStorage.restore`
/// （box 単位に `clear()` して `putAll`）で行われる。したがって差分の意味論は
/// 「バックアップに載っている許可リスト内 box の各キー」について:
/// - 現状に無い → 新規（created）
/// - 現状と値が違う → 上書き（overwritten）
/// - 同値 → 変更なし（unchanged）
/// - 現状に在るがバックアップに無い → 削除（deleted）
///
/// 許可リスト外 box・秘密キーは復元で無視されるため計上しない。
/// プレイヤー／クエストは復元で丸ごと置き換わるため別枠で持つ。
class RestorePreview {
  /// 新規作成されるキー数。
  final int created;

  /// 上書きされるキー数。
  final int overwritten;

  /// 変更の無いキー数。
  final int unchanged;

  /// バックアップに無いため消えるキー数。
  final int deleted;

  /// 上書き対象キーの先頭 [kRestorePreviewSampleLimit] 件（`box/key` 昇順）。
  final List<String> overwriteSampleKeys;

  /// 抜粋から漏れた上書き対象キー数。
  final int hiddenOverwriteCount;

  /// プレイヤー情報が置き換わるか。
  final bool playerReplaced;

  /// 置き換わるクエスト数。
  final int tasksReplaced;

  const RestorePreview({
    required this.created,
    required this.overwritten,
    required this.unchanged,
    required this.deleted,
    required this.overwriteSampleKeys,
    required this.hiddenOverwriteCount,
    required this.playerReplaced,
    required this.tasksReplaced,
  });

  /// 差分の総件数（バックアップに含まれる対象キー数）。
  int get total => created + overwritten + unchanged + deleted;

  /// 復元対象が何かしら存在するか。
  bool get hasAny => total > 0 || playerReplaced || tasksReplaced > 0;

  /// 書き換えが1件でも起きるか。
  bool get hasChanges =>
      created > 0 ||
      overwritten > 0 ||
      deleted > 0 ||
      playerReplaced ||
      tasksReplaced > 0;

  /// 要約行。例: `新規 12件 / 上書き 340件 / 変更なし 8件 / 削除 2件`
  String get summary {
    final parts = <String>[
      '新規 $created件',
      '上書き $overwritten件',
      '変更なし $unchanged件',
    ];
    if (deleted > 0) {
      parts.add('削除 $deleted件');
    }
    return parts.join(' / ');
  }

  /// プレイヤー／クエストの置き換えを伝える一文。無ければ null。
  String? get replacedText {
    if (playerReplaced && tasksReplaced > 0) {
      return 'プレイヤー情報とクエスト $tasksReplaced件も置き換わります';
    }
    if (playerReplaced) return 'プレイヤー情報も置き換わります';
    if (tasksReplaced > 0) return 'クエスト $tasksReplaced件も置き換わります';
    return null;
  }

  /// 上書き対象キーの抜粋。上書き0件なら null（表示しない）。
  ///
  /// 例:
  /// ```
  /// 上書きされるキー:
  /// ・battle_records/streak
  /// ・settingsBox/fontSizeScale
  /// ほか 3件
  /// ```
  String? get samplesText {
    if (overwriteSampleKeys.isEmpty) return null;
    final buffer = StringBuffer('上書きされるキー:');
    for (final key in overwriteSampleKeys) {
      buffer.write('\n・$key');
    }
    if (hiddenOverwriteCount > 0) {
      buffer.write('\nほか $hiddenOverwriteCount件');
    }
    return buffer.toString();
  }

  /// 状況に応じた一文（境界ごとに言い回しを変える）。
  String get message {
    if (!hasAny) return '復元対象のデータはありません';
    if (!hasChanges) return '現在のデータと一致しています。変更はありません';
    if (created == 0 && overwritten == 0 && deleted == 0) {
      return 'プレイヤー情報とクエストが置き換わります';
    }
    if (overwritten == 0 && deleted == 0) {
      return '既存データは上書きされません（新規データのみ追加されます）';
    }
    if (created == 0 && deleted == 0) {
      return '新規データはありません。既存データが上書きされます';
    }
    if (created == 0 && overwritten == 0) {
      return '新規・上書きはありません。バックアップに無いデータが削除されます';
    }
    return '新規データの追加と、既存データの上書きが行われます';
  }

  /// [FullBackupData] と現状スナップショットからプレビューを組み立てる。
  ///
  /// - 上書き対象キーは決定的（昇順）に並べ、先頭 [sampleLimit] 件を抜粋する
  /// - [sampleLimit] が 0 以下なら [ArgumentError]
  static RestorePreview build({
    required FullBackupData backup,
    required Map<String, Map<String, dynamic>> currentBoxes,
    int sampleLimit = kRestorePreviewSampleLimit,
  }) {
    if (sampleLimit <= 0) {
      throw ArgumentError.value(sampleLimit, 'sampleLimit', 'must be > 0');
    }

    var created = 0;
    var overwritten = 0;
    var unchanged = 0;
    var deleted = 0;
    final overwriteKeys = <String>[];

    backup.boxes.forEach((boxName, entries) {
      // 許可リスト外 box は復元で無視されるため計上しない。
      if (BackupBoxRegistry.specFor(boxName) == null) return;
      final current = currentBoxes[boxName] ?? const <String, dynamic>{};
      entries.forEach((key, value) {
        // 秘密キーは復元で捨てられるため計上しない。
        if (isSecretKey(key)) return;
        if (!current.containsKey(key)) {
          created++;
        } else if (!_valueEquals(current[key], value)) {
          overwritten++;
          overwriteKeys.add('$boxName/$key');
        } else {
          unchanged++;
        }
      });
      // restore は clear() してから putAll するため、控えに無い現状キーは消える。
      for (final key in current.keys) {
        if (isSecretKey(key)) continue;
        if (!entries.containsKey(key)) deleted++;
      }
    });

    overwriteKeys.sort();
    final sample = List<String>.unmodifiable(overwriteKeys.take(sampleLimit));

    return RestorePreview(
      created: created,
      overwritten: overwritten,
      unchanged: unchanged,
      deleted: deleted,
      overwriteSampleKeys: sample,
      hiddenOverwriteCount: overwriteKeys.length - sample.length,
      // decode は player が Map でない控えを null で弾くため、復元可能な控えは
      // 必ずプレイヤーを持つ（＝プレイヤーは必ず置き換わる）。
      playerReplaced: true,
      tasksReplaced: backup.tasks.length,
    );
  }

  /// 破損・空・巨大入力でも throw せず、分類不能なら null を返す入口。
  static RestorePreview? tryFromJson({
    required String backupJson,
    required Map<String, Map<String, dynamic>> currentBoxes,
    int sampleLimit = kRestorePreviewSampleLimit,
  }) {
    try {
      final data = FullBackupService().decode(backupJson);
      if (data == null) return null;
      final preview = build(
        backup: data,
        currentBoxes: currentBoxes,
        sampleLimit: sampleLimit,
      );
      // 表示する内訳が1件も無い（box 0件・クエスト0件）なら非表示。
      if (preview.total == 0 && preview.tasksReplaced == 0) return null;
      return preview;
    } catch (_) {
      return null;
    }
  }

  /// スナップショット値の同値判定（List/Map は要素比較）。
  static bool _valueEquals(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_valueEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_valueEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }
}
