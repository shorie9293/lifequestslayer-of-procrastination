import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/auto_backup/domain/backup_restorability.dart';

/// decode を通る最小の正当な控え。
String validBackupJson() => jsonEncode({
      'version': 2,
      'exportedAt': '2026-10-28T00:00:00.000Z',
      'player': Player().toJson(),
      'tasks': <dynamic>[],
      'boxes': <String, dynamic>{},
    });

void main() {
  group('classify: 4分類', () {
    test('null は empty', () {
      final r = BackupRestorability.classify(null);
      expect(r.state, BackupRestoreState.empty);
      expect(r.isRestorable, isFalse);
      expect(r.label, '空です');
    });

    test('空文字・空白のみは empty', () {
      expect(BackupRestorability.classify('').state, BackupRestoreState.empty);
      expect(
          BackupRestorability.classify('   ').state, BackupRestoreState.empty);
      expect(BackupRestorability.classify('\n\t ').state,
          BackupRestoreState.empty);
    });

    test('壊れた JSON は corrupt', () {
      final r = BackupRestorability.classify('not json');
      expect(r.state, BackupRestoreState.corrupt);
      expect(r.isRestorable, isFalse);
      expect(r.label, 'JSONが壊れています');
    });

    test('トップが Map でない（配列・文字列・数値）は corrupt', () {
      expect(
          BackupRestorability.classify('[]').state, BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('"text"').state,
          BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('123').state,
          BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('true').state,
          BackupRestoreState.corrupt);
    });

    test('版番号が無い控えは unsupportedVersion（理由を明示）', () {
      final r = BackupRestorability.classify(
        jsonEncode({'player': Player().toJson(), 'tasks': <dynamic>[]}),
      );
      expect(r.state, BackupRestoreState.unsupportedVersion);
      expect(r.isRestorable, isFalse);
      expect(r.reason, contains('版番号が無い控えはこの版では復元できません'));
      expect(r.label, '版番号が無い控えです');
    });

    test('version の型違いは unsupportedVersion', () {
      final r = BackupRestorability.classify(
        jsonEncode({
          'version': '2',
          'player': Player().toJson(),
          'tasks': <dynamic>[],
        }),
      );
      expect(r.state, BackupRestoreState.unsupportedVersion);
    });

    test('version = 0 は unsupportedVersion', () {
      final r = BackupRestorability.classify(
        jsonEncode({
          'version': 0,
          'player': Player().toJson(),
          'tasks': <dynamic>[],
        }),
      );
      expect(r.state, BackupRestoreState.unsupportedVersion);
    });

    test('版番号はあるが中身が復元形式に合わない場合は corrupt', () {
      final r = BackupRestorability.classify('{"version":2}');
      expect(r.state, BackupRestoreState.corrupt);
      expect(r.reason, contains('中身が復元形式に合いません'));
    });

    test('decode を通る最小 JSON は restorable', () {
      final r = BackupRestorability.classify(validBackupJson());
      expect(r.state, BackupRestoreState.restorable);
      expect(r.isRestorable, isTrue);
      expect(r.label, '復元可能');
      expect(r.reason, isNotEmpty);
    });
  });

  group('classify: 絶対に throw しない', () {
    test('1MB の壊れ文字列でも throw しない', () {
      final huge = 'x' * (1024 * 1024);
      late BackupRestorability r;
      expect(() => r = BackupRestorability.classify(huge), returnsNormally);
      expect(r.state, BackupRestoreState.corrupt);
    });

    test('1MB の切り詰め JSON でも throw しない', () {
      final huge = '{"version":2,"player":${'[' * 1000}';
      expect(() => BackupRestorability.classify(huge), returnsNormally);
    });

    test('あらゆる入力で例外を投げない', () {
      const inputs = <String?>[
        null,
        '',
        ' ',
        '{',
        '}',
        'null',
        '[]',
        '{}',
        '{"version":null}',
        '{"version":-1}',
        '{"version":1.5}',
        '{"version":2,"player":[],"tasks":[]}',
        '{"version":2,"player":{},"tasks":[]}',
      ];
      for (final input in inputs) {
        expect(
          () => BackupRestorability.classify(input),
          returnsNormally,
          reason: 'input=$input',
        );
      }
    });
  });

  group('値オブジェクト', () {
    test('const で生成でき、state と reason を保持する', () {
      const r = BackupRestorability(
        BackupRestoreState.corrupt,
        '理由',
      );
      expect(r.state, BackupRestoreState.corrupt);
      expect(r.reason, '理由');
      expect(r.isRestorable, isFalse);
    });

    test('restorable の isRestorable は true', () {
      const r = BackupRestorability(BackupRestoreState.restorable, '復元可能');
      expect(r.isRestorable, isTrue);
    });
  });
}
