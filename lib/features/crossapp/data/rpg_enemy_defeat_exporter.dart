import 'dart:convert';
import 'dart:io';

/// rpg-task の敵討伐イベントを共有ストレージへ書き出すエクスポーター
///
/// kozuchi が読み取れるよう、単一JSONファイルに enemy_defeated イベントを書く。
/// パス: /data/local/tmp/takamagahara_shared/rpg_enemy_defeat_events.json
///
/// スキーマは kozuchi の `RpgTaskBonusService` の消費契約に合わせる:
/// `{event: 'enemy_defeated', taskTitle, questRank, baseExp, timestamp}`
/// （kozuchi は読取後にファイルを削除して重複付与を防ぐ、1イベント1ファイル設計）。
///
/// 書き込みはベストエフォート。失敗しても討伐の本処理を妨げないよう
/// 例外は握りつぶす（テスト環境等で /data が書けない場合に単体テストを壊さない防御）。
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

/// ファイルベースの [IRpgEnemyDefeatExporter] 実装
class RpgEnemyDefeatExporter implements IRpgEnemyDefeatExporter {
  /// 出力先ファイルパス
  final String filePath;

  const RpgEnemyDefeatExporter({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/rpg_enemy_defeat_events.json',
  });

  @override
  Future<void> exportEnemyDefeat({
    required String taskTitle,
    required String questRank,
    required int baseExp,
    String? timestamp,
  }) async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);

      final json = {
        'event': 'enemy_defeated',
        'taskTitle': taskTitle,
        'questRank': questRank.toUpperCase(),
        'baseExp': baseExp,
        'timestamp': timestamp ?? DateTime.now().toUtc().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // 共有ストレージ書込はオプション機能。失敗は握りつぶす（ベストエフォート）。
    }
  }
}
