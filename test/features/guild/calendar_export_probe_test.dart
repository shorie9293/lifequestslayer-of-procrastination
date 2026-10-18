// 親探針: 画面→サービス→ICS の合成不変条件（虚偽件数の防止）。
//
// 眷属の試練は層ごとに個別検証しがちなので、
// 「画面が表示する件数」と「実際に書き出される予定数」の一致を親が撃つ。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_export/data/ics_share_exporter.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_keys.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_screen.dart';

class _RecordingExporter implements IcsShareExporter {
  String? ics;

  @override
  Future<void> share({
    required String ics,
    required String fileName,
    required String text,
  }) async {
    this.ics = ics;
  }
}

Task _task(String id, String title, DateTime? deadline) =>
    Task(id: id, title: title, deadline: deadline);

final _now = DateTime(2026, 10, 19, 9);

final _tasks = <Task>[
  _task('a', '本日締切', DateTime(2026, 10, 19)),
  _task('b', '三日後', DateTime(2026, 10, 22)),
  _task('c', '期限なし', null),
  Task(id: 'd', title: '完了済み', deadline: DateTime(2026, 10, 20), isCompleted: true),
];

int _veventCount(String ics) =>
    RegExp(r'BEGIN:VEVENT\r\n').allMatches(ics).length;

void main() {
  testWidgets('件数ラベルと書き出した VEVENT 数が一致し、期限なしは載らない',
      (tester) async {
    final fake = _RecordingExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarExportScreen(
          tasksOverride: _tasks,
          exporter: fake,
          now: _now,
        ),
      ),
    );
    await tester.pump();

    // 未完了かつ期限ありは2件（期限なし・完了済みは書き出せない）。
    expect(find.text('2件を書き出します'), findsOneWidget);
    expect(find.textContaining('期限なし'), findsNothing);

    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(fake.ics, isNotNull);
    expect(_veventCount(fake.ics!), 2);
  });

  testWidgets('DTSTART は期限の日付（8桁・時刻なし）で出力される', (tester) async {
    final fake = _RecordingExporter();
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarExportScreen(
          tasksOverride: _tasks,
          exporter: fake,
          now: _now,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    final ics = fake.ics!;
    expect(ics, contains('DTSTART;VALUE=DATE:20261019'));
    expect(ics, contains('DTSTART;VALUE=DATE:20261022'));
    // 時刻付きの DTSTART を混在させない。
    expect(ics, isNot(contains('DTSTART:2026')));
    expect(ics, contains('UID:task-a@takamagahara'));
  });
}
