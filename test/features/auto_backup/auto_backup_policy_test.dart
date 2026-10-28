import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';

void main() {
  const policy = AutoBackupPolicy();
  final base = DateTime(2026, 10, 29, 9, 0);

  group('AutoBackupEntry', () {
    test('値等価と hashCode が一致する', () {
      final a = AutoBackupEntry(fileName: 'auto_backup_20261029.json', createdAt: base);
      final b = AutoBackupEntry(fileName: 'auto_backup_20261029.json', createdAt: base);
      final c = AutoBackupEntry(fileName: 'auto_backup_20261028.json', createdAt: base);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('shouldRun', () {
    test('lastAt が null なら実行する', () {
      expect(policy.shouldRun(lastAt: null, now: base), isTrue);
    });

    test('23時間59分では実行しない', () {
      final lastAt = base.subtract(const Duration(hours: 23, minutes: 59));
      expect(policy.shouldRun(lastAt: lastAt, now: base), isFalse);
    });

    test('ちょうど24時間で実行する', () {
      final lastAt = base.subtract(const Duration(hours: 24));
      expect(policy.shouldRun(lastAt: lastAt, now: base), isTrue);
    });

    test('未来時刻の lastAt でも実行する（時計巻き戻し対策）', () {
      final lastAt = base.add(const Duration(days: 3));
      expect(policy.shouldRun(lastAt: lastAt, now: base), isTrue);
    });
  });

  group('fileNameFor / isAutoBackupFile', () {
    test('年月日をゼロ埋めして決定的に生成する', () {
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 7, 5, 23, 59)),
        'auto_backup_20260705.json',
      );
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 12, 31)),
        'auto_backup_20261231.json',
      );
      final d = DateTime(2026, 1, 2, 3, 4);
      expect(AutoBackupPolicy.fileNameFor(d), AutoBackupPolicy.fileNameFor(d));
    });

    test('ローカル暦を使い UTC 変換しない', () {
      final local = DateTime(2026, 10, 29, 1, 30);
      expect(AutoBackupPolicy.fileNameFor(local), 'auto_backup_20261029.json');
    });

    test('自動バックアップ名のみ一致する', () {
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20261029.json'), isTrue);
      expect(AutoBackupPolicy.isAutoBackupFile('manual_backup.json'), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20261029.txt'), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_.json'), isTrue);
    });
  });

  group('latestCreatedAt', () {
    test('自動ファイルの最大 createdAt を返し、手動ファイルは無視する', () {
      final entries = [
        AutoBackupEntry(fileName: 'auto_backup_20261027.json', createdAt: base.subtract(const Duration(days: 2))),
        AutoBackupEntry(fileName: 'auto_backup_20261028.json', createdAt: base.subtract(const Duration(days: 1))),
        AutoBackupEntry(fileName: 'manual.json', createdAt: base.add(const Duration(days: 9))),
      ];
      expect(policy.latestCreatedAt(entries), base.subtract(const Duration(days: 1)));
    });

    test('空・自動ファイルなしは null', () {
      expect(policy.latestCreatedAt(const []), isNull);
      expect(
        policy.latestCreatedAt([
          AutoBackupEntry(fileName: 'manual.json', createdAt: base),
        ]),
        isNull,
      );
    });

    test('同時刻はファイル名降順で安定する', () {
      final same = base;
      final entries = [
        AutoBackupEntry(fileName: 'auto_backup_20261027.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_20261028.json', createdAt: same),
      ];
      expect(policy.latestCreatedAt(entries), same);
      // 同値でも並びに依存しない
      expect(policy.latestCreatedAt(entries.reversed.toList()), same);
    });
  });

  group('prune', () {
    List<AutoBackupEntry> fiveAuto() => [
          for (var i = 0; i < 5; i++)
            AutoBackupEntry(
              fileName: 'auto_backup_2026100${i + 1}.json',
              createdAt: base.subtract(Duration(days: 5 - i)),
            ),
        ];

    test('keep=3 で新しい3件を残し、古い2件を削除対象にする', () {
      final pruned = policy.prune(fiveAuto());
      expect(pruned.map((e) => e.fileName).toList(), [
        'auto_backup_20261002.json',
        'auto_backup_20261001.json',
      ]);
    });

    test('3件以下なら削除対象なし', () {
      expect(policy.prune(fiveAuto().skip(2).toList()), isEmpty);
      expect(policy.prune(const []), isEmpty);
    });

    test('手動ファイルは絶対に削除対象にしない', () {
      final entries = [
        ...fiveAuto(),
        AutoBackupEntry(fileName: 'manual_backup.json', createdAt: base.subtract(const Duration(days: 400))),
        AutoBackupEntry(
          fileName: 'takamagahara_manual_backup.json',
          createdAt: base.subtract(const Duration(days: 500)),
        ),
      ];
      final pruned = policy.prune(entries);
      expect(pruned.any((e) => !AutoBackupPolicy.isAutoBackupFile(e.fileName)), isFalse);
      expect(pruned.length, 2);
    });

    test('同時刻はファイル名降順でタイブレークする', () {
      final same = base;
      final entries = [
        AutoBackupEntry(fileName: 'auto_backup_20261001.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_20261002.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_20261003.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_20261004.json', createdAt: same),
      ];
      final pruned = policy.prune(entries);
      expect(pruned.map((e) => e.fileName).toList(), ['auto_backup_20261001.json']);
    });

    test('カスタム keep=1 で最古のみ残す', () {
      const p = AutoBackupPolicy(keep: 1);
      final pruned = p.prune(fiveAuto());
      expect(pruned.length, 4);
      expect(pruned.map((e) => e.fileName), isNot(contains('auto_backup_20261005.json')));
    });
  });
}
