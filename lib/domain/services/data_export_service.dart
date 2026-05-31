import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';

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
