import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';

/// 自動バックアップの保存先抽象。
abstract interface class AutoBackupStore {
  /// 保存済みバックアップの一覧（手動ファイルを含みうる）。
  Future<List<AutoBackupEntry>> list();

  /// [fileName] へ書き込む（同名は上書き＝冪等）。
  Future<void> write(String fileName, String json);

  /// [fileName] を削除する。
  Future<void> delete(String fileName);

  /// [fileName] の本文を読む。存在しなければ null。
  Future<String?> read(String fileName);
}

/// 試練用のメモリ内実装。
///
/// [now] を注入すると createdAt を試練の時計に同期できる。
class InMemoryAutoBackupStore implements AutoBackupStore {
  InMemoryAutoBackupStore({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, _StoredBackup> _files = {};

  @override
  Future<List<AutoBackupEntry>> list() async => _files.entries
      .map((e) => AutoBackupEntry(
            fileName: e.key,
            createdAt: e.value.createdAt,
          ))
      .toList(growable: false);

  @override
  Future<void> write(String fileName, String json) async {
    final existing = _files[fileName];
    _files[fileName] = _StoredBackup(
      json: json,
      // 同日上書きは作成時刻を保つ（冪等・世代順序の安定）。
      createdAt: existing?.createdAt ?? _now(),
    );
  }

  @override
  Future<void> delete(String fileName) async {
    _files.remove(fileName);
  }

  /// 保存内容を読み出す（試練用のメモリ実装）。
  @override
  Future<String?> read(String fileName) async => _files[fileName]?.json;
}

class _StoredBackup {
  const _StoredBackup({required this.json, required this.createdAt});

  final String json;
  final DateTime createdAt;
}

/// 端末ドキュメント配下 `auto_backups/` に実ファイルとして保存する実装。
///
/// [directoryResolver] を注入すると試練で任意ディレクトリを使える。
class FileAutoBackupStore implements AutoBackupStore {
  FileAutoBackupStore({Future<Directory> Function()? directoryResolver})
      : _directoryResolver =
            directoryResolver ?? getApplicationDocumentsDirectory;

  static const String directoryName = 'auto_backups';

  final Future<Directory> Function() _directoryResolver;

  Future<Directory> _ensureDirectory() async {
    final base = await _directoryResolver();
    final dir = Directory('${base.path}${Platform.pathSeparator}$directoryName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<List<AutoBackupEntry>> list() async {
    final dir = await _ensureDirectory();
    final entries = <AutoBackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      if (!AutoBackupPolicy.isAutoBackupFile(name)) continue;
      final parsed = _createdAtFromName(name);
      if (parsed != null) {
        entries.add(AutoBackupEntry(fileName: name, createdAt: parsed));
        continue;
      }
      try {
        final stat = await entity.stat();
        entries.add(AutoBackupEntry(fileName: name, createdAt: stat.modified));
      } catch (e) {
        debugPrint('[auto_backup] stat 失敗: $name ($e)');
      }
    }
    return entries;
  }

  @override
  Future<void> write(String fileName, String json) async {
    final dir = await _ensureDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(json, flush: true);
  }

  @override
  Future<String?> read(String fileName) async {
    final dir = await _ensureDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } catch (e) {
      debugPrint('[auto_backup] read 失敗: $fileName ($e)');
      return null;
    }
  }

  @override
  Future<void> delete(String fileName) async {
    final dir = await _ensureDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String _basename(String path) {
    final index = path.lastIndexOf(Platform.pathSeparator);
    return index < 0 ? path : path.substring(index + 1);
  }

  /// `auto_backup_yyyyMMdd.json` からローカル暦の日付を復元する。
  static DateTime? _createdAtFromName(String name) {
    if (!AutoBackupPolicy.isAutoBackupFile(name)) return null;
    final body = name.substring(
      AutoBackupPolicy.filePrefix.length,
      name.length - AutoBackupPolicy.fileSuffix.length,
    );
    if (body.length != 8) return null;
    final year = int.tryParse(body.substring(0, 4));
    final month = int.tryParse(body.substring(4, 6));
    final day = int.tryParse(body.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
