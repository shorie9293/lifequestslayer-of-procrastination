import 'dart:convert';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// 道標§五#17: データエクスポート＆バックアップ可視化の中核ロジック。
///
/// Hive 永続化の詳細（Box 操作・アダプタ）は呼び出し側が担い、
/// 本サービスは直列化・復元の純粋ロジックのみを提供する:
///
/// 1. [buildBackupJson] — Player + Task 一覧をバージョン付き JSON エンベロープに直列化
/// 2. [parseBackupJson] — エンベロープを検証し、復元可能な [BackupSnapshot] を返す
///
/// バージョン不整合・不正 JSON は [FormatException] を投げる（安全な復元を担保）。
class BackupService {
  BackupService._();

  /// 現在のバックアップ形式バージョン。
  /// 形式を変える（フィールド追加/削除）際は必ず increment すること。
  static const int currentVersion = 1;

  /// エンベロープのルートキー名。
  static const String _versionKey = 'version';
  static const String _exportedAtKey = 'exportedAt';
  static const String _playerKey = 'player';
  static const String _tasksKey = 'tasks';

  /// Player と Task 一覧をバージョン付き JSON エンベロープに直列化する。
  static String buildBackupJson({
    required Player? player,
    required List<Task> tasks,
    required DateTime exportedAt,
  }) {
    final envelope = <String, dynamic>{
      _versionKey: currentVersion,
      _exportedAtKey: exportedAt.toIso8601String(),
      _playerKey: player?.toJson(),
      _tasksKey: tasks.map((t) => t.toJson()).toList(),
    };
    return jsonEncode(envelope);
  }

  /// エンベロープを検証し、復元可能な [BackupSnapshot] を返す。
  ///
  /// - 不正な JSON → [FormatException]
  /// - 対応していないバージョン → [FormatException]
  /// - tasks フィールドが List でない → [FormatException]
  static BackupSnapshot parseBackupJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (e) {
      throw FormatException('バックアップJSONのパースに失敗: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('バックアップ形式が不正（ルートがオブジェクトでない）');
    }

    final version = decoded[_versionKey];
    if (version is! int || version != currentVersion) {
      throw FormatException(
          '非対応バージョンのバックアップです（現在: $currentVersion, 検出: $version）');
    }

    Player? player;
    final playerRaw = decoded[_playerKey];
    if (playerRaw != null) {
      if (playerRaw is! Map<String, dynamic>) {
        throw const FormatException('player フィールドが不正です');
      }
      player = Player.fromJson(playerRaw);
    }

    final tasksRaw = decoded[_tasksKey];
    if (tasksRaw is! List) {
      throw const FormatException('tasks フィールドが不正です');
    }
    final tasks = tasksRaw
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();

    return BackupSnapshot(player: player, tasks: tasks);
  }
}

/// 復元可能なバックアップスナップショット。
class BackupSnapshot {
  const BackupSnapshot({required this.player, required this.tasks});

  final Player? player;
  final List<Task> tasks;
}
