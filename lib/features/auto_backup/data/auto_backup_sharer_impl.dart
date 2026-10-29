import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:share_plus/share_plus.dart';

/// share_plus による自動バックアップ共有の本番実装。
///
/// 本文を一時ファイルへ書き出し、既存のバックアップ共有と同じ導線で共有する。
class AutoBackupSharerImpl implements AutoBackupSharer {
  const AutoBackupSharerImpl();

  @override
  Future<void> share(String fileName, String json) async {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.isEmpty ? 'auto_backup.json' : fileName;
    final file = File('${dir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(json, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'RPG Task バックアップ $safeName',
    );
  }
}
