// データの持ち出し／取り込み（2026-11-28: 寺院画面から移設）。
//
// 寺院は「遊び（転職・技）」の画面であるべきで、JSONバックアップ・復元・CSV書き出しは
// 管理操作なので設定へ集約した（1機能1入口）。挙動は移設前と同一で、
// 画面のキーも同じものを使う（既存の自動操作・試練がそのまま辿れる）。
//
// 自動バックアップ（設定ハブ）は「アプリが保存した世代を戻す」経路。
// こちらは「自分で持ち出した/持ち込んだファイル」を扱う経路で、役割が異なる。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/data_export_service.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/auto_backup/domain/restore_preview.dart';
import 'package:rpg_todo/features/auto_backup/presentation/restore_preview_dialog.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';

/// バックアップ JSON を組み立てる（storage から boxes を capture する）。
Future<String> buildManualBackupJson({
  required Player player,
  required List<Task> tasks,
  required BackupStorage storage,
}) async {
  final boxes = await storage.capture();
  return FullBackupService().encode(
    player: player,
    tasks: tasks,
    boxes: boxes,
    exportedAt: DateTime.now(),
  );
}

/// 復元用 JSON を player / tasks / boxes へ適用する。
///
/// 成功で true、decode 失敗（破損 JSON 等）で false。
Future<bool> applyManualRestore({
  required String jsonString,
  required PlayerViewModel playerVM,
  required TaskViewModel taskVM,
  required BackupStorage storage,
}) async {
  final data = FullBackupService().decode(jsonString);
  if (data == null) return false;
  playerVM.restorePlayer(data.player);
  taskVM.setTasks(data.tasks);
  await storage.restore(data.boxes);
  return true;
}

/// 設定ハブの「データの持ち出し／取り込み」節。
class DataPortabilitySection extends StatefulWidget {
  const DataPortabilitySection({super.key, this.storageFactory});

  /// 保存先（試練での注入用。未指定なら Hive）。
  final BackupStorage Function()? storageFactory;

  @override
  State<DataPortabilitySection> createState() => _DataPortabilitySectionState();
}

class _DataPortabilitySectionState extends State<DataPortabilitySection> {
  BackupStorage _storage() =>
      (widget.storageFactory ?? (() => HiveBackupStorage()))();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: AppKeys.templeBackupButton,
          leading: const Icon(Icons.backup),
          title: const Text('バックアップをファイルに書き出す'),
          subtitle: const Text('端末の全データを JSON で共有する'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _exportBackup,
        ),
        ListTile(
          key: AppKeys.templeRestoreButton,
          leading: const Icon(Icons.restore),
          title: const Text('バックアップをファイルから復元'),
          subtitle: const Text('書き出した JSON を読み込んで戻す'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _importBackup,
        ),
        ListTile(
          key: AppKeys.templeCsvExportButton,
          leading: const Icon(Icons.table_view),
          title: const Text('クエストをCSVで書き出す'),
          subtitle: const Text('一覧を表計算ソフトで扱える形で共有する'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _exportCsv,
        ),
      ],
    );
  }

  Future<void> _exportBackup() async {
    final playerVM = context.read<PlayerViewModel>();
    final taskVM = context.read<TaskViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await buildManualBackupJson(
        player: playerVM.player,
        tasks: taskVM.tasks,
        storage: _storage(),
      );
      await DataExportService().exportStringToFile(json);
      messenger.showSnackBar(
        const SnackBar(content: Text('バックアップを共有しました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('バックアップに失敗しました')),
      );
    }
  }

  Future<void> _importBackup() async {
    final playerVM = context.read<PlayerViewModel>();
    final taskVM = context.read<TaskViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final String? json;
    try {
      json = await DataExportService().importStringFromFile();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('復元に失敗しました')));
      return;
    }
    if (json == null) {
      messenger.showSnackBar(const SnackBar(content: Text('復元に失敗しました')));
      return;
    }
    final storage = _storage();
    RestorePreview? preview;
    try {
      final boxes = await storage.capture();
      preview = RestorePreview.tryFromJson(
        backupJson: json,
        currentBoxes: boxes,
      );
    } catch (_) {
      preview = null;
    }
    if (!mounted) return;
    final confirmed = await showRestorePreviewDialog(
      context: context,
      dialogKey: AppKeys.templeRestoreConfirmDialog,
      message: 'このバックアップから復元しますか？現在のデータは先に自動バックアップされます',
      preview: preview,
      cancelKey: AppKeys.templeRestoreCancelButton,
      confirmKey: AppKeys.templeRestoreConfirmButton,
    );
    if (!confirmed) return;
    final ok = await applyManualRestore(
      jsonString: json,
      playerVM: playerVM,
      taskVM: taskVM,
      storage: storage,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'データを復元しました' : '復元に失敗しました')),
    );
  }

  Future<void> _exportCsv() async {
    final taskVM = context.read<TaskViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DataExportService().exportTasksCsvToFile(taskVM.tasks);
      messenger.showSnackBar(
        const SnackBar(content: Text('クエスト一覧をCSVで共有しました')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('CSV書き出しに失敗しました')));
    }
  }
}
