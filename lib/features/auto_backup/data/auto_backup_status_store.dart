import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';

/// 自動バックアップの状態（最終成功・最終試行・失敗理由）の保存先。
abstract class AutoBackupStatusStore {
  /// 保存済みの状態を読み出す（無ければ null）。
  Future<AutoBackupStatus?> read();

  /// 状態を保存する（上書き）。
  Future<void> write(AutoBackupStatus status);
}

/// テスト用のインメモリ実装。
class InMemoryAutoBackupStatusStore implements AutoBackupStatusStore {
  AutoBackupStatus? _status;

  /// 初期状態を注入できる（テスト用）。
  InMemoryAutoBackupStatusStore([this._status]);

  @override
  Future<AutoBackupStatus?> read() async => _status;

  @override
  Future<void> write(AutoBackupStatus status) async {
    _status = status;
  }
}

/// ドキュメント配下 `auto_backups/auto_backup_status.json` に保存する実装。
///
/// ファイル名は `auto_backup_yyyyMMdd.json` の命名規約に一致しないため、
/// 自動バックアップの一覧・世代整理には現れない。
class FileAutoBackupStatusStore implements AutoBackupStatusStore {
  FileAutoBackupStatusStore({Future<Directory> Function()? directoryResolver})
      : _directoryResolver =
            directoryResolver ?? getApplicationDocumentsDirectory;

  /// 状態ファイル名。
  static const String fileName = 'auto_backup_status.json';

  /// 保存先ディレクトリ名（[FileAutoBackupStore] と同一）。
  static const String directoryName = 'auto_backups';

  final Future<Directory> Function() _directoryResolver;

  Future<File> _file() async {
    final base = await _directoryResolver();
    final dir = Directory('${base.path}${Platform.pathSeparator}$directoryName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<AutoBackupStatus?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return AutoBackupStatus.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AutoBackupStatus status) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(status.toJson()), flush: true);
  }
}
