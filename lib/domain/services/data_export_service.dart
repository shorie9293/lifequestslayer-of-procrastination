import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/csv_export_service.dart';

/// JSONを介したデータのエクスポート/インポートを担当するサービス。
///
/// フォーマット:
/// ```json
/// {
///   "version": 1,
///   "exportedAt": "2026-05-31T09:52:00.000",
///   "player": { ... },
///   "tasks": [ ... ]
/// }
/// ```
class DataExportService {
  /// Player + TaskリストをJSON文字列にエクスポートする。
  String exportToJson(Player player, List<Task> tasks) {
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'player': player.toJson(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
    });
  }

  /// JSON文字列を解析して Player + Taskリストを復元する。
  ///
  /// パースに失敗した場合は `null` を返す。
  ({Player player, List<Task> tasks})? importFromJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['version'] as int?;
      if (version == null || version < 1) return null;

      final player =
          Player.fromJson(data['player'] as Map<String, dynamic>);
      final tasks = (data['tasks'] as List<dynamic>)
          .map((t) => Task.fromJson(t as Map<String, dynamic>))
          .toList();
      return (player: player, tasks: tasks);
    } catch (_) {
      return null;
    }
  }

  /// Player + Taskリストを一時ファイルに書き出し、share_plus で共有する。
  Future<void> exportToFile(Player player, List<Task> tasks) async {
    final jsonStr = exportToJson(player, tasks);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/rpg_todo_backup.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'RPG Task バックアップ',
    );
  }

  /// 任意の JSON 文字列（全データバックアップ等）を一時ファイルへ書き出し、
  /// share_plus で共有する。
  Future<void> exportStringToFile(String jsonString) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/rpg_todo_full_backup.json');
    await file.writeAsString(jsonString);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'RPG Task 全データバックアップ',
    );
  }

  /// クエスト一覧を UTF-8 BOM 付き CSV として一時ファイルに書き出し、
  /// share_plus で共有する。
  ///
  /// BOM は文字列ではなくバイト列（0xEF,0xBB,0xBF）として先頭に固定するため、
  /// [csvBytes] を [File.writeAsBytes] で書く。
  Future<void> exportTasksCsvToFile(List<Task> tasks) async {
    final csv = exportTasksCsv(tasks);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/rpg_quests_$stamp.csv');
    await file.writeAsBytes(csvBytes(csv), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'RPG Task クエスト一覧',
    );
  }

  /// file_picker で .json ファイルを選び、本文（JSON 文字列）を返す。
  ///
  /// キャンセル時や読み込み失敗時は `null` を返す。
  Future<String?> importStringFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return null;
      final filePath = result.files.single.path;
      if (filePath == null) return null;
      return await File(filePath).readAsString();
    } catch (_) {
      return null;
    }
  }

  /// file_picker で .json ファイルを選択し、読み込んでパースする。
  ///
  /// ユーザーがキャンセルした場合やパースに失敗した場合は `null` を返す。
  Future<({Player player, List<Task> tasks})?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final filePath = result.files.single.path;
    if (filePath == null) return null;
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    return importFromJson(jsonStr);
  }
}
