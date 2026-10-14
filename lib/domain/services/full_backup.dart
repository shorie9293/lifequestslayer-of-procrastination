import 'dart:convert';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// 全データバックアップのデータ本体（version 2 形式）。
class FullBackupData {
  final int version;
  final DateTime exportedAt;
  final Player player;
  final List<Task> tasks;

  /// boxName -> {key: JSON値}
  final Map<String, Map<String, dynamic>> boxes;

  const FullBackupData({
    required this.version,
    required this.exportedAt,
    required this.player,
    required this.tasks,
    this.boxes = const {},
  });

  bool get hasBoxes => boxes.isNotEmpty;

  int get boxCount => boxes.length;

  /// 全 box の entry（key）総数。
  int get entryCount =>
      boxes.values.fold(0, (sum, entries) => sum + entries.length);

  List<String> get boxNames => boxes.keys.toList(growable: false);
}

/// 全データバックアップの encode / decode を担うサービス（純粋 Dart）。
class FullBackupService {
  static const int currentVersion = 2;

  /// Player + Tasks + boxes を version 2 JSON に直列化する。
  String encode({
    required Player player,
    required List<Task> tasks,
    Map<String, Map<String, dynamic>> boxes = const {},
    DateTime? exportedAt,
  }) {
    return jsonEncode({
      'version': currentVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'player': player.toJson(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'boxes': boxes,
    });
  }

  /// JSON 文字列を復元する。
  ///
  /// - パース失敗 / Map でない / version 欠落 / version < 1 → null
  /// - version == 1: boxes は空として復元（後方互換）
  /// - version >= 2: boxes を読み取る（非 Map の要素は無視）
  /// - player / tasks の欠落・不正 → null
  /// - 未知のトップレベルキー・未知 box 名は保持（前方互換）
  FullBackupData? decode(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final version = decoded['version'];
    if (version is! int || version < 1) return null;

    final playerJson = decoded['player'];
    if (playerJson is! Map<String, dynamic>) return null;

    final tasksJson = decoded['tasks'];
    if (tasksJson is! List<dynamic>) return null;

    final Player player;
    final List<Task> tasks;
    try {
      player = Player.fromJson(playerJson);
      tasks = tasksJson
          .map((t) => Task.fromJson(t as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }

    var boxes = const <String, Map<String, dynamic>>{};
    if (version >= 2) {
      final boxesJson = decoded['boxes'];
      if (boxesJson is Map<String, dynamic>) {
        final parsed = <String, Map<String, dynamic>>{};
        boxesJson.forEach((boxName, entries) {
          // 値が Map でない要素は無視
          if (entries is Map<String, dynamic>) {
            final safeEntries = <String, dynamic>{};
            entries.forEach((key, value) {
              // JSON 直列化可能でない値は無視（例外は投げない）
              if (_isJsonSafe(value)) {
                safeEntries[key] = value;
              }
            });
            parsed[boxName] = safeEntries;
          }
        });
        boxes = parsed;
      }
    }

    final exportedAtStr = decoded['exportedAt'];
    final exportedAt = exportedAtStr is String
        ? DateTime.tryParse(exportedAtStr)
        : null;

    return FullBackupData(
      version: version,
      exportedAt: exportedAt ?? DateTime.now(),
      player: player,
      tasks: tasks,
      boxes: boxes,
    );
  }

  /// 値が JSON 直列化可能（String/num/bool/null/List/Map）か再帰的に判定する。
  static bool _isJsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return true;
    }
    if (value is List) {
      return value.every(_isJsonSafe);
    }
    if (value is Map) {
      return value.keys.every((k) => k is String) &&
          value.values.every(_isJsonSafe);
    }
    return false;
  }
}
