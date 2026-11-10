import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/features/auto_backup/domain/restore_preview.dart';

String backupJson({
  Map<String, dynamic>? boxes,
  Map<String, dynamic>? player,
  List<dynamic>? tasks,
}) =>
    jsonEncode({
      'version': 2,
      'exportedAt': '2026-11-11T00:00:00.000Z',
      'player': player ?? Player().toJson(),
      'tasks': tasks ?? <dynamic>[],
      'boxes': boxes ?? <String, dynamic>{},
    });

void main() {
  group('RestorePreview.build — rpg の適用意味論', () {
    test('新規・上書き・変更なし・削除を数え、上書きキーを昇順で抜粋する', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(boxes: {
          'battle_records': {'a': 1, 'b': 2, 'c': 3},
          'settingsBox': {'fontSizeScale': 1.0},
          // 許可リスト外 box は復元されないので計上しない。
          'unknown_box': {'z': 9},
        }),
        currentBoxes: {
          'battle_records': {'a': 1, 'b': 9, 'x': 0},
          'settingsBox': {'fontSizeScale': 1.0},
        },
      );

      expect(preview, isNotNull);
      expect(preview!.created, 1); // c
      expect(preview.overwritten, 1); // b
      expect(preview.unchanged, 2); // a, fontSizeScale
      expect(preview.deleted, 1); // x
      expect(preview.total, 5);
      expect(preview.overwriteSampleKeys, ['battle_records/b']);
      expect(preview.hiddenOverwriteCount, 0);
      expect(preview.summary, '新規 1件 / 上書き 1件 / 変更なし 2件 / 削除 1件');
      expect(preview.samplesText, '上書きされるキー:\n・battle_records/b');
      expect(preview.hasChanges, isTrue);
    });

    test('上書きキーは昇順・上限5件で、漏れ件数を返す', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(boxes: {
          'battle_records': {
            for (var i = 6; i >= 0; i--) 'k$i': i,
          },
        }),
        currentBoxes: {
          'battle_records': {
            for (var i = 6; i >= 0; i--) 'k$i': -1,
          },
        },
      )!;

      expect(preview.overwritten, 7);
      expect(preview.overwriteSampleKeys, [
        'battle_records/k0',
        'battle_records/k1',
        'battle_records/k2',
        'battle_records/k3',
        'battle_records/k4'
      ]);
      expect(preview.hiddenOverwriteCount, 2);
      expect(preview.samplesText, contains('ほか 2件'));
    });

    test('同値の List / Map は変更なしに計上する', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(boxes: {
          'battle_records': {
            'list': [1, 2, 3],
            'map': {
              'a': 1,
              'b': {'c': 2}
            },
          },
        }),
        currentBoxes: {
          'battle_records': {
            'list': [1, 2, 3],
            'map': {
              'a': 1,
              'b': {'c': 2}
            },
          },
        },
      )!;

      expect(preview.created, 0);
      expect(preview.overwritten, 0);
      expect(preview.unchanged, 2);
      // プレイヤーは復元で置き換わるため「変更あり」。
      expect(preview.hasChanges, isTrue);
      expect(preview.message, 'プレイヤー情報とクエストが置き換わります');
    });

    test('秘密キーは復元されないため新規・削除のどちらにも数えない', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(boxes: {
          'settingsBox': {
            'appLock.passcodeHash': 'hash-from-backup',
            'fontSizeScale': 1.0,
          },
        }),
        currentBoxes: {
          'settingsBox': {'appLock.passcodeHash': 'local-hash'},
        },
      )!;

      expect(preview.created, 1); // fontSizeScale
      expect(preview.deleted, 0); // 秘密キーは消えない扱い
      expect(preview.overwritten, 0);
      expect(preview.unchanged, 0);
    });

    test('box に無い現状キーは削除に数える（clear+putAll の意味論）', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(boxes: {
          'battle_records': <String, dynamic>{},
        }),
        currentBoxes: {
          'battle_records': {'old': 1},
        },
      )!;

      expect(preview.created, 0);
      expect(preview.deleted, 1);
      expect(preview.total, 1);
      expect(preview.message, '新規・上書きはありません。バックアップに無いデータが削除されます');
    });

    test('プレイヤー／クエストの置き換えを別枠で返す', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(tasks: [
          Task(id: 't1', title: 'クエスト').toJson(),
        ]),
        currentBoxes: const {},
      )!;

      expect(preview.total, 0);
      expect(preview.playerReplaced, isTrue);
      expect(preview.tasksReplaced, 1);
      expect(preview.replacedText, 'プレイヤー情報とクエスト 1件も置き換わります');
      expect(preview.message, 'プレイヤー情報とクエストが置き換わります');
    });

    test('sampleLimit 0 以下は ArgumentError', () {
      expect(
        () => RestorePreview.build(
          backup: _decoded(backupJson()),
          currentBoxes: const {},
          sampleLimit: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('RestorePreview.tryFromJson — 壊れた入力で throw しない', () {
    for (final input in <String>[
      '',
      '   ',
      'not json',
      '{}',
      'null',
      '[]',
      '{"version":2}',
      '{"version":999,"player":null,"tasks":[]}',
      '{"version":2,"player":{"broken":true},"tasks":[]}',
      '{"version":2,"player":null,"tasks":[],"boxes":{"battle_records":"oops"}}',
      '[[[[[[[[[[[[[[[[[[[[',
    ]) {
      test(
          '入力「${input.length > 20 ? '${input.substring(0, 20)}…' : input}」は null',
          () {
        expect(
          RestorePreview.tryFromJson(
            backupJson: input,
            currentBoxes: const {},
          ),
          isNull,
        );
      });
    }

    test('0件の控え（box 0・クエスト0）はプレビュー非表示', () {
      expect(
        RestorePreview.tryFromJson(
          backupJson: backupJson(),
          currentBoxes: const {},
        ),
        isNull,
      );
    });

    test('巨大入力（2MB）でも throw せず null', () {
      final huge = 'a' * (2 * 1024 * 1024);
      expect(
        RestorePreview.tryFromJson(backupJson: huge, currentBoxes: const {}),
        isNull,
      );
    });

    test('現状スナップショットが壊れていても throw しない', () {
      final preview = RestorePreview.tryFromJson(
        backupJson: backupJson(boxes: {
          'battle_records': {'a': 1},
        }),
        currentBoxes: {'battle_records': <String, dynamic>{}},
      );
      expect(preview, isNotNull);
      expect(preview!.created, 1);
    });
  });
}

FullBackupData _decoded(String json) {
  final data = FullBackupService().decode(json);
  if (data == null) {
    throw StateError('fixture must decode');
  }
  return data;
}
