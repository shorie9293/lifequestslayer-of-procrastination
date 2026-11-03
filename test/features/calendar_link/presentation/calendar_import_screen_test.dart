import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_link/data/calendar_gateway.dart';
import 'package:rpg_todo/features/calendar_link/domain/calendar_import_service.dart';
import 'package:rpg_todo/features/calendar_link/domain/linked_calendar_event.dart';
import 'package:rpg_todo/features/calendar_link/presentation/calendar_import_screen.dart';
import 'package:rpg_todo/features/calendar_link/presentation/calendar_link_keys.dart';

/// 端末APIに触れないフェイク。
class _FakeCalendarGateway implements CalendarGateway {
  _FakeCalendarGateway({
    this.status = CalendarAccessStatus.granted,
    this.events = const <LinkedCalendarEvent>[],
    this.supported = true,
    this.throwOnRead = false,
  });

  final CalendarAccessStatus status;
  final List<LinkedCalendarEvent> events;
  final bool supported;
  final bool throwOnRead;

  @override
  bool get isSupported => supported;

  @override
  Future<CalendarAccessStatus> ensureAccess() async => status;

  @override
  Future<List<LinkedCalendarEvent>> readEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    if (throwOnRead) {
      throw const CalendarGatewayException('端末カレンダーが応答しません');
    }
    return events;
  }
}

LinkedCalendarEvent _event({
  String id = 'e1',
  String title = '定例MTG',
  required DateTime start,
  int minutes = 60,
}) {
  return LinkedCalendarEvent(
    eventId: id,
    calendarId: 'cal',
    title: title,
    start: start,
    end: start.add(Duration(minutes: minutes)),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required CalendarGateway gateway,
  List<Task> tasks = const <Task>[],
  DateTime? now,
  void Function(List<Task>)? onImport,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: CalendarImportScreen(
      gateway: gateway,
      tasksOverride: tasks,
      now: now ?? DateTime(2026, 11, 3, 8),
      onImport: onImport,
      idGenerator: () => 'generated',
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime(2026, 11, 3, 8);

  testWidgets('読み込み中はインジケータ、完了後に件数と予定が出る', (tester) async {
    final gateway = _FakeCalendarGateway(events: <LinkedCalendarEvent>[
      _event(title: '朝会', start: DateTime(2026, 11, 3, 9)),
      _event(id: 'e2', title: '夕会', start: DateTime(2026, 11, 3, 18)),
    ]);

    await _pump(tester, gateway: gateway, now: now);

    expect(find.byKey(CalendarLinkAppKeys.eventList), findsOneWidget);
    expect(find.text('2件の予定（2件を選択中）'), findsOneWidget);
    expect(find.text('朝会'), findsOneWidget);
    expect(find.text('夕会'), findsOneWidget);
    expect(find.text('2件を取り込む'), findsOneWidget);
  });

  testWidgets('取り込むとクエストが受け渡され、画面が閉じる', (tester) async {
    List<Task>? imported;
    final gateway = _FakeCalendarGateway(events: <LinkedCalendarEvent>[
      _event(title: '朝会', start: DateTime(2026, 11, 3, 9)),
    ]);

    await _pump(
      tester,
      gateway: gateway,
      now: now,
      onImport: (tasks) => imported = tasks,
    );
    await tester.tap(find.byKey(CalendarLinkAppKeys.importButton));
    await tester.pumpAndSettle();

    expect(imported, hasLength(1));
    expect(imported!.single.title, '朝会');
    expect(imported!.single.id, 'generated');
    expect(imported!.single.deadline, DateTime(2026, 11, 3, 9));
  });

  testWidgets('チェックを外した予定は取り込まない', (tester) async {
    List<Task>? imported;
    final gateway = _FakeCalendarGateway(events: <LinkedCalendarEvent>[
      _event(title: '朝会', start: DateTime(2026, 11, 3, 9)),
      _event(id: 'e2', title: '夕会', start: DateTime(2026, 11, 3, 18)),
    ]);

    await _pump(
      tester,
      gateway: gateway,
      now: now,
      onImport: (tasks) => imported = tasks,
    );
    await tester.tap(find.byKey(CalendarLinkAppKeys.eventTile('e2')));
    await tester.pump();
    expect(find.text('1件を取り込む'), findsOneWidget);

    await tester.tap(find.byKey(CalendarLinkAppKeys.importButton));
    await tester.pumpAndSettle();

    expect(imported!.single.title, '朝会');
  });

  testWidgets('予定が無ければ空状態を出し、取り込みボタンは押せない', (tester) async {
    await _pump(tester, gateway: _FakeCalendarGateway(), now: now);

    expect(find.byKey(CalendarLinkAppKeys.emptyState), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(CalendarLinkAppKeys.importButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('既存クエストと重複する予定は一覧に出さない', (tester) async {
    final gateway = _FakeCalendarGateway(events: <LinkedCalendarEvent>[
      _event(title: '定例MTG', start: DateTime(2026, 11, 3, 10)),
    ]);
    final existing = <Task>[
      Task(id: 't1', title: '定例MTG', deadline: DateTime(2026, 11, 3, 10)),
    ];

    await _pump(tester, gateway: gateway, tasks: existing, now: now);

    expect(find.byKey(CalendarLinkAppKeys.emptyState), findsOneWidget);
  });

  testWidgets('権限拒否なら理由と再試行を出す', (tester) async {
    await _pump(
      tester,
      gateway: _FakeCalendarGateway(status: CalendarAccessStatus.denied),
      now: now,
    );

    expect(find.byKey(CalendarLinkAppKeys.permissionDenied), findsOneWidget);
    expect(find.byKey(CalendarLinkAppKeys.retryButton), findsOneWidget);
  });

  testWidgets('非対応プラットフォームなら対応外の案内を出す', (tester) async {
    await _pump(
      tester,
      gateway: _FakeCalendarGateway(
        supported: false,
        status: CalendarAccessStatus.unsupported,
      ),
      now: now,
    );

    expect(find.byKey(CalendarLinkAppKeys.unsupported), findsOneWidget);
    expect(find.textContaining('Android 版のみ'), findsOneWidget);
  });

  testWidgets('読み取り失敗ならエラー文言と再試行を出す', (tester) async {
    await _pump(
      tester,
      gateway: _FakeCalendarGateway(throwOnRead: true),
      now: now,
    );

    expect(find.byKey(CalendarLinkAppKeys.errorState), findsOneWidget);
    expect(find.text('端末カレンダーが応答しません'), findsOneWidget);
    expect(find.byKey(CalendarLinkAppKeys.retryButton), findsOneWidget);
  });

  testWidgets('期間チップを変えると対象が絞られる', (tester) async {
    final gateway = _FakeCalendarGateway(events: <LinkedCalendarEvent>[
      _event(title: '今日の予定', start: DateTime(2026, 11, 3, 9)),
      _event(id: 'e2', title: '5日後の予定', start: DateTime(2026, 11, 8, 9)),
    ]);

    await _pump(tester, gateway: gateway, now: now);
    expect(find.text('1件の予定（1件を選択中）'), findsOneWidget);

    await tester.tap(find.byKey(
        CalendarLinkAppKeys.rangeChip(CalendarImportRange.next7Days)));
    await tester.pumpAndSettle();

    expect(find.text('2件の予定（2件を選択中）'), findsOneWidget);
    expect(find.text('5日後の予定'), findsOneWidget);
  });
}
