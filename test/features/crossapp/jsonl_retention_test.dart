import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/crossapp/domain/jsonl_retention.dart';

String _line(String id, {String userId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', String eventType = 'book_completed'}) {
  return jsonEncode({
    'event_id': id,
    'event_type': eventType,
    'timestamp': '2026-06-07T10:30:00Z',
    'user_id': userId,
    'metadata': const {'count': 1},
  });
}

void main() {
  group('buildJsonlRetentionPlan', () {
    test('処理済み行だけを落とし、未処理行は必ず残す', () {
      final lines = <String>[
        _line('e1'),
        _line('e2'),
        _line('e3'),
      ];

      final plan = buildJsonlRetentionPlan(
        lines,
        consumedIds: <String>{'e1', 'e2'},
      );

      expect(plan.retainedLines, <String>[_line('e3')]);
      expect(plan.droppedConsumed, 2);
      expect(plan.pendingCount, 1);
      expect(plan.shouldRewrite, isTrue);
      expect(plan.content.trim().split('\n').length, 1);
    });

    test('全て未処理なら書き戻さない（shouldRewrite=false）', () {
      final lines = <String>[_line('e1'), _line('e2')];
      final plan = buildJsonlRetentionPlan(lines, consumedIds: <String>{});

      expect(plan.retainedLines.length, 2);
      expect(plan.shouldRewrite, isFalse);
      expect(plan.pendingCount, 2);
    });

    test('全行処理済みなら空本文になる', () {
      final lines = <String>[_line('e1'), _line('e2')];
      final plan = buildJsonlRetentionPlan(
        lines,
        consumedIds: <String>{'e1', 'e2'},
      );

      expect(plan.retainedLines, isEmpty);
      expect(plan.content, '');
      expect(plan.droppedConsumed, 2);
    });

    test('順序を保つ（未処理行は元の並びのまま）', () {
      final lines = <String>[
        _line('e1'),
        _line('e2'),
        _line('e3'),
        _line('e4'),
      ];
      final plan = buildJsonlRetentionPlan(
        lines,
        consumedIds: <String>{'e2'},
      );

      expect(
        plan.retainedLines.map((l) => jsonDecode(l)['event_id']).toList(),
        <String>['e1', 'e3', 'e4'],
      );
    });

    test('壊れた行・空行があっても throw しない', () {
      final lines = <String>[
        '',
        '   ',
        '{壊れた JSON',
        '{"event_id": 123}',
        '[]',
        _line('e1'),
      ];

      late JsonlRetentionPlan plan;
      expect(() {
        plan = buildJsonlRetentionPlan(lines, consumedIds: <String>{});
      }, returnsNormally);

      // 壊れ行3件は既定上限10件以内ゆえ保持、空行2件は捨てる。
      expect(plan.droppedEmpty, 2);
      expect(plan.pendingCount, 1);
      expect(plan.retainedLines.length, 4);
    });

    test('壊れた行は直近 maxRetainedCorrupt 件だけ残す', () {
      final lines = <String>[
        for (var i = 0; i < 30; i++) '壊れ行$i',
      ];

      final plan = buildJsonlRetentionPlan(
        lines,
        consumedIds: <String>{},
        maxRetainedCorrupt: 3,
      );

      expect(plan.retainedLines, <String>['壊れ行27', '壊れ行28', '壊れ行29']);
      expect(plan.droppedCorrupt, 27);
      expect(plan.shouldRewrite, isTrue);
    });

    test('1000行（995件が処理済み）で解析行数が上限以下になる', () {
      final lines = <String>[
        for (var i = 0; i < 995; i++) _line('consumed-$i'),
        for (var i = 0; i < 5; i++) _line('pending-$i'),
      ];
      final consumed = <String>{for (var i = 0; i < 995; i++) 'consumed-$i'};

      final plan = buildJsonlRetentionPlan(lines, consumedIds: consumed);

      expect(plan.parseLineCount, 5);
      expect(plan.parseLineCount, lessThanOrEqualTo(200));
      expect(plan.pendingCount, 5);
    });

    test('未処理行は件数上限でも落とさない（不変条件）', () {
      final lines = <String>[for (var i = 0; i < 1000; i++) _line('p-$i')];

      final plan = buildJsonlRetentionPlan(lines, consumedIds: <String>{});

      expect(plan.retainedLines.length, 1000);
      expect(plan.shouldRewrite, isFalse);
    });

    test('preservedEventTypes に載る種別は処理済みでも保持する', () {
      final lines = <String>[
        _line('b1'),
        _line('s1', eventType: 'reading_streak'),
      ];
      final plan = buildJsonlRetentionPlan(
        lines,
        consumedIds: <String>{'b1', 's1'},
        preservedEventTypes: <String>{'book_completed'},
      );

      expect(plan.retainedLines.length, 1);
      expect(plan.retainedLines.single, contains('book_completed'));
      expect(plan.preservedCount, 1);
      expect(plan.droppedConsumed, 1);
      expect(plan.shouldRewrite, isTrue);
    });

    test('event_id が空文字の行は壊れ行として扱う', () {
      final lines = <String>[
        jsonEncode({
          'event_id': '',
          'event_type': 'book_completed',
          'timestamp': '2026-06-07T10:30:00Z',
          'user_id': 'a1b2c3d4',
        }),
      ];

      final plan = buildJsonlRetentionPlan(lines, consumedIds: <String>{});
      expect(plan.pendingCount, 0);
      expect(plan.retainedLines.length, 1);
    });
  });
}
