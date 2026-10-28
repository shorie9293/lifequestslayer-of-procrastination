/// 起動時自動バックアップの世代管理ポリシー（現世共通仕様）。
///
/// 保存先・間隔・世代数といった判断はすべてここに閉じ込め、
/// サービスは I/O 順序のみを担う。
class AutoBackupEntry {
  final String fileName;
  final DateTime createdAt;

  const AutoBackupEntry({required this.fileName, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      other is AutoBackupEntry &&
      other.fileName == fileName &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(fileName, createdAt);

  @override
  String toString() => 'AutoBackupEntry($fileName, $createdAt)';
}

class AutoBackupPolicy {
  /// 既定の世代保持数（最新3世代）。
  static const int defaultKeep = 3;

  /// 既定の実行間隔（1日1回）。
  static const Duration defaultInterval = Duration(hours: 24);

  /// 自動バックアップファイル名の接頭辞。
  static const String filePrefix = 'auto_backup_';

  /// 自動バックアップファイル名の接尾辞。
  static const String fileSuffix = '.json';

  final Duration interval;
  final int keep;

  const AutoBackupPolicy({
    this.interval = defaultInterval,
    this.keep = defaultKeep,
  });

  /// 実行すべきか。
  ///
  /// - [lastAt] が null（未実行）なら true
  /// - 経過が [interval] 以上なら true（ちょうど24時間も実行）
  /// - 未来時刻の [lastAt]（時計巻き戻し）でも true＝永久に走らない事故を防ぐ
  bool shouldRun({DateTime? lastAt, required DateTime now}) {
    if (lastAt == null) return true;
    if (now.isBefore(lastAt)) return true;
    return now.difference(lastAt) >= interval;
  }

  /// ローカル暦の年月日から決定論的なファイル名を作る（UTC 変換しない）。
  static String fileNameFor(DateTime now) {
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$filePrefix${now.year}$month$day$fileSuffix';
  }

  /// 自動バックアップのファイル名か（手動バックアップを巻き込まないための門番）。
  static bool isAutoBackupFile(String name) =>
      name.startsWith(filePrefix) && name.endsWith(fileSuffix);

  /// 自動バックアップのみを対象とした最新の作成時刻。無ければ null。
  DateTime? latestCreatedAt(List<AutoBackupEntry> entries) {
    final auto = _autoEntries(entries);
    if (auto.isEmpty) return null;
    return auto.first.createdAt;
  }

  /// 削除対象（古い世代）を返す。手動ファイルは絶対に返さない。
  ///
  /// 自動ファイルを createdAt 降順（同値は fileName 降順）に並べ、
  /// 先頭 [keep] 件を残して残りを削除対象とする。
  List<AutoBackupEntry> prune(List<AutoBackupEntry> entries) {
    final auto = _autoEntries(entries);
    if (auto.length <= keep) return const [];
    return auto.sublist(keep.clamp(0, auto.length));
  }

  /// 自動ファイルのみを新しい順に整列した複製。
  List<AutoBackupEntry> _autoEntries(List<AutoBackupEntry> entries) {
    final auto = entries
        .where((e) => isAutoBackupFile(e.fileName))
        .toList(growable: false);
    final sorted = List<AutoBackupEntry>.of(auto);
    sorted.sort(_newestFirst);
    return sorted;
  }

  /// createdAt 降順 → fileName 降順の安定した比較。
  static int _newestFirst(AutoBackupEntry a, AutoBackupEntry b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) return byTime;
    return b.fileName.compareTo(a.fileName);
  }
}
