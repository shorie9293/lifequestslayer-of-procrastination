import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_presenter.dart';

void main() {
  group('formatDate', () {
    test('ローカル暦を yyyy-MM-dd HH:mm で表す（UTC変換しない）', () {
      final at = DateTime(2026, 10, 29, 7, 12);
      expect(AutoBackupPresenter.formatDate(at), '2026-10-29 07:12');
    });

    test('1桁の月日時分はゼロ埋めする', () {
      final at = DateTime(2026, 1, 2, 3, 4);
      expect(AutoBackupPresenter.formatDate(at), '2026-01-02 03:04');
    });
  });

  group('formatSize', () {
    test('1024未満はバイト表記', () {
      expect(AutoBackupPresenter.formatSize(0), '0 B');
      expect(AutoBackupPresenter.formatSize(512), '512 B');
      expect(AutoBackupPresenter.formatSize(1023), '1023 B');
    });

    test('1024以上は KB（小数1桁）', () {
      expect(AutoBackupPresenter.formatSize(1024), '1.0 KB');
      expect(AutoBackupPresenter.formatSize(1536), '1.5 KB');
    });

    test('1MB以上は MB（小数1桁）', () {
      expect(AutoBackupPresenter.formatSize(1048576), '1.0 MB');
      expect(AutoBackupPresenter.formatSize(1290000), '1.2 MB');
    });
  });

  group('canRestore', () {
    test('null・空・壊れたJSONは false', () {
      expect(AutoBackupPresenter.canRestore(null), isFalse);
      expect(AutoBackupPresenter.canRestore(''), isFalse);
      expect(AutoBackupPresenter.canRestore('{'), isFalse);
    });

    test('トップが Map でなければ false', () {
      expect(AutoBackupPresenter.canRestore('[]'), isFalse);
      expect(AutoBackupPresenter.canRestore('"text"'), isFalse);
      expect(AutoBackupPresenter.canRestore('123'), isFalse);
    });

    test('トップが Map なら true', () {
      expect(AutoBackupPresenter.canRestore('{"a":1}'), isTrue);
    });
  });

  group('sortNewestFirst', () {
    test('createdAt 降順、同値は fileName 降順', () {
      final entries = [
        AutoBackupEntry(
          fileName: 'auto_backup_20261027.json',
          createdAt: DateTime(2026, 10, 27),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20261029.json',
          createdAt: DateTime(2026, 10, 29),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20261028.json',
          createdAt: DateTime(2026, 10, 28),
        ),
      ];
      final sorted = AutoBackupPresenter.sortNewestFirst(entries).map((e) => e.fileName).toList();
      expect(sorted, [
        'auto_backup_20261029.json',
        'auto_backup_20261028.json',
        'auto_backup_20261027.json',
      ]);
      // 元リストは破壊しない
      expect(entries.first.fileName, 'auto_backup_20261027.json');
    });

    test('同時刻は fileName 降順', () {
      final at = DateTime(2026, 10, 29);
      final entries = [
        AutoBackupEntry(fileName: 'auto_backup_20261029.json', createdAt: at),
        AutoBackupEntry(fileName: 'auto_backup_20261028.json', createdAt: at),
      ];
      final sorted = AutoBackupPresenter.sortNewestFirst(entries).map((e) => e.fileName).toList();
      expect(sorted, [
        'auto_backup_20261029.json',
        'auto_backup_20261028.json',
      ]);
    });
  });

  group('buildRows', () {
    test('自動ファイルのみ・新しい順・世代1始まり・サイズ・復元可否', () {
      final entries = [
        AutoBackupEntry(
          fileName: 'manual_backup.json',
          createdAt: DateTime(2026, 10, 30),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20261029.json',
          createdAt: DateTime(2026, 10, 29),
        ),
        AutoBackupEntry(
          fileName: 'auto_backup_20261028.json',
          createdAt: DateTime(2026, 10, 28),
        ),
      ];
      final contents = {
        'manual_backup.json': '{"manual":true}',
        'auto_backup_20261029.json': '{"a":1}',
        'auto_backup_20261028.json': 'not json',
      };

      final rows = const AutoBackupPresenter()
          .buildRows(entries: entries, contents: contents);

      expect(rows.length, 2);
      expect(rows[0].entry.fileName, 'auto_backup_20261029.json');
      expect(rows[0].generation, 1);
      expect(rows[0].byteSize, 7);
      expect(rows[0].restorable, isTrue);
      expect(rows[1].entry.fileName, 'auto_backup_20261028.json');
      expect(rows[1].generation, 2);
      expect(rows[1].restorable, isFalse);
    });

    test('content が null なら byteSize 0・復元不可', () {
      final entries = [
        AutoBackupEntry(
          fileName: 'auto_backup_20261029.json',
          createdAt: DateTime(2026, 10, 29),
        ),
      ];
      final rows = const AutoBackupPresenter()
          .buildRows(entries: entries, contents: const {});
      expect(rows.single.byteSize, 0);
      expect(rows.single.restorable, isFalse);
    });

    test('displayLabel は日付 / サイズ / 世代', () {
      final entries = [
        AutoBackupEntry(
          fileName: 'auto_backup_20261029.json',
          createdAt: DateTime(2026, 10, 29, 7, 12),
        ),
      ];
      final json = List<String>.filled(12700, 'x').join(); // 12.4 KB
      final rows = const AutoBackupPresenter().buildRows(
        entries: entries,
        contents: {'auto_backup_20261029.json': json},
      );
      expect(rows.single.displayLabel, '2026-10-29 07:12 / 12.4 KB / 第1世代');
      expect(rows.single.dateLabel, '2026-10-29 07:12');
      expect(rows.single.sizeLabel, '12.4 KB');
    });

    test('retentionLabel は保持世代数と件数', () {
      expect(const AutoBackupPresenter().retentionLabel(2), '保持 3世代中 2件');
      expect(
        const AutoBackupPresenter(keep: 5).retentionLabel(5),
        '保持 5世代中 5件',
      );
    });
  });
}
