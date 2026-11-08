import 'dart:convert';
import 'dart:io';

import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';
import 'package:rpg_todo/features/crossapp/domain/enemy_defeat_event.dart';

/// rpg-task の敵討伐イベントを共有ストレージへ書き出すエクスポーター
///
/// kozuchi が読み取れるよう、同一呼出で2ファイルへ書く（契約 v1）:
/// - A: `rpg_enemy_defeat_events.json`  — 直近1件の単一JSON。
///   kozuchi の `RpgTaskBonusService` が読み取り後に削除する既存挙動を保持する。
/// - B: `rpg_enemy_defeat_events.jsonl` — 追記専用。1行1コンパクトJSON。
///   kozuchi の集計が `event` フィールドで行数を数える。
///
/// 双方のスキーマは同一:
/// `{event: 'enemy_defeated', taskTitle, questRank, baseExp, timestamp}`
///
/// 書き込みはベストエフォート。失敗しても討伐の本処理を妨げないよう
/// 例外は握りつぶす。2ファイルは独立に試行するため、片方の失敗が
/// もう片方を巻き添えにしない。
abstract class IRpgEnemyDefeatExporter {
  /// 敵討伐イベントを共有ストレージへ書き出す
  ///
  /// [taskTitle] 討伐したクエストのタイトル
  /// [questRank] クエストランク（S/A/B、大文字に正規化）
  /// [baseExp]   討伐で得たベースEXP
  /// [timestamp] 討伐日時（ISO8601文字列、省略時は現在時刻）
  Future<void> exportEnemyDefeat({
    required String taskTitle,
    required String questRank,
    required int baseExp,
    String? timestamp,
  });
}

/// [IRpgEnemyDefeatExporter] の実装。
///
/// 保存先は [SharedFileStore] が解決する（Android 実機では SAF の共有フォルダ）。
/// [filePath] を明示した場合のみ、そのパスへ直接書く（試練用の後方互換）。
class RpgEnemyDefeatExporter implements IRpgEnemyDefeatExporter {
  /// 試練用の明示パス（単一JSON側）。null なら共有ストア経由。
  final String? filePath;

  /// 時刻供給（試練で決定的にするため注入可能）
  final DateTime Function() clock;

  const RpgEnemyDefeatExporter({
    this.filePath,
    this.clock = DateTime.now,
  });

  /// 追記専用 jsonl のパス。`.json` 拡張子を `.jsonl` に置換して導出する。
  String get jsonlPath => filePath!.toLowerCase().endsWith('.json')
      ? '${filePath!.substring(0, filePath!.length - 5)}.jsonl'
      : '$filePath.jsonl';

  @override
  Future<void> exportEnemyDefeat({
    required String taskTitle,
    required String questRank,
    required int baseExp,
    String? timestamp,
  }) async {
    final event = buildEnemyDefeatEvent(
      taskTitle: taskTitle,
      questRank: questRank,
      baseExp: baseExp,
      timestamp: timestamp ?? formatTimestamp(clock()),
    );

    if (filePath != null) {
      await _writeToFile(event);
      return;
    }
    await _writeToStore(event);
  }

  /// 試練用: 明示パスへの直書き（従来の契約をそのまま保持）。
  Future<void> _writeToFile(Map<String, dynamic> event) async {
    // A: 直近1件の単一JSON（上書き）
    try {
      final file = File(filePath!);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(event), flush: true);
    } catch (_) {
      // 共有ストレージ書込はオプション機能。失敗は握りつぶす（ベストエフォート）。
    }

    // B: 追記専用 jsonl（1行1コンパクトJSON）
    try {
      final line = encodeEventLine(event);
      final jsonlFile = File(jsonlPath);
      await jsonlFile.parent.create(recursive: true);
      await jsonlFile.writeAsString('$line\n',
          mode: FileMode.append, flush: true);
    } catch (_) {
      // 同上。追記失敗も討伐本処理を妨げない。
    }
  }

  /// 本番: 共有ストア経由（Android 実機では SAF の共有フォルダ）。
  ///
  /// 書込失敗は**握りつぶさず** [SharedStorageException] として伝える。
  /// 呼び出し側（討伐の本処理）はこの例外を「連携失敗」として記録し、
  /// 討伐そのものは止めない。
  Future<void> _writeToStore(Map<String, dynamic> event) async {
    final store = SharedFileStore.instance;

    // A: 直近1件の単一JSON（上書き）
    await store.writeString(
      SharedCrossAppFiles.rpgEnemyDefeatJson,
      jsonEncode(event),
    );

    // B: 追記専用 jsonl（1行1コンパクトJSON）
    await store.appendLine(
      SharedCrossAppFiles.rpgEnemyDefeatJsonl,
      encodeEventLine(event),
    );
  }
}
