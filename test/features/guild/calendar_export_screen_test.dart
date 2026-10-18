// カレンダー書き出し画面の試練（fake 共有exporter 注入・now 固定）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_export/data/ics_share_exporter.dart';
import 'package:rpg_todo/features/calendar_export/domain/task_calendar_export_service.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_keys.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_screen.dart';

class _FakeExporter implements IcsShareExporter {
  _FakeExporter({this.throwOnShare = false});

  final bool throwOnShare;
  String? ics;
  String? fileName;
  String? text;
  int calls = 0;

  @override
  Future<void> share({
    required String ics,
    required String fileName,
    required String text,
  }) async {
    calls++;
    this.ics = ics;
    this.fileName = fileName;
    this.text = text;
    if (throwOnShare) throw Exception('share failed');
  }
}

Task _t(String id, String title, DateTime? deadline) =>
    Task(id: id, title: title, deadline: deadline);

final _now = DateTime(2026, 10, 19, 9, 0);

final _tasks = <Task>[
  _t('1', '討伐クエスト', DateTime(2026, 10, 19)),
  _t('2', '薬草集め', DateTime(2026, 10, 22)),
  _t('3', '遠征', DateTime(2026, 11, 15)),
  _t('4', '期限なしクエスト', null),
];

Future<void> _pump(
  WidgetTester tester, {
  required List<Task> tasks,
  required IcsShareExporter exporter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CalendarExportScreen(
        tasksOverride: tasks,
        exporter: exporter,
        now: _now,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('件数ラベルとプレビューを表示する', (tester) async {
    final fake = _FakeExporter();
    await _pump(tester, tasks: _tasks, exporter: fake);

    expect(find.text('3件を書き出します'), findsOneWidget);
    expect(find.text('10/19 討伐クエスト'), findsOneWidget);
    expect(find.text('11/15 遠征'), findsOneWidget);
  });

  testWidgets('範囲チップの切替で件数が変わる', (tester) async {
    final fake = _FakeExporter();
    await _pump(tester, tasks: _tasks, exporter: fake);

    expect(
      find.byKey(
          CalendarExportAppKeys.rangeChip(CalendarExportRange.next7Days)),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
          CalendarExportAppKeys.rangeChip(CalendarExportRange.next7Days)),
    );
    await tester.pumpAndSettle();
    expect(find.text('2件を書き出します'), findsOneWidget);

    await tester.tap(
      find.byKey(
          CalendarExportAppKeys.rangeChip(CalendarExportRange.withDeadline)),
    );
    await tester.pumpAndSettle();
    expect(find.text('3件を書き出します'), findsOneWidget);
  });

  testWidgets('書き出しタップで fake が VEVENT とタイトルを含む ics を受け取る', (tester) async {
    final fake = _FakeExporter();
    await _pump(tester, tasks: _tasks, exporter: fake);

    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(fake.ics, contains('BEGIN:VEVENT'));
    expect(fake.ics, contains('SUMMARY:討伐クエスト'));
    expect(fake.fileName, 'rpg_quests.ics');
    expect(fake.text, 'クエスト期限を書き出しました');
  });

  testWidgets('0件なら書き出しボタンは無効', (tester) async {
    final fake = _FakeExporter();
    await _pump(tester, tasks: const [], exporter: fake);

    final button = tester.widget<ElevatedButton>(
      find.byKey(CalendarExportAppKeys.exportButton),
    );
    expect(button.onPressed, isNull);
    expect(find.text('0件を書き出します'), findsOneWidget);
    expect(find.byKey(CalendarExportAppKeys.emptyState), findsOneWidget);
  });

  testWidgets('共有失敗時は SnackBar を出す', (tester) async {
    final fake = _FakeExporter(throwOnShare: true);
    await _pump(tester, tasks: _tasks, exporter: fake);

    await tester.tap(find.byKey(CalendarExportAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(find.text('書き出しに失敗しました'), findsOneWidget);
  });
}
