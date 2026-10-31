import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/crash/crash_log_entry.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

CrashLogEntry _entry(int i) => CrashLogEntry(
      timestamp: DateTime(2026, 11, 1, 12, i),
      kind: 'zone',
      message: 'error $i',
      stackTop: '#0 frame $i',
    );

void main() {
  testWidgets('サマリー1行と直近エントリ一覧を表示する', (tester) async {
    final repo = InMemoryCrashLogRepository([_entry(1), _entry(2)]);
    await tester.pumpWidget(MaterialApp(
      home: CrashLogScreen(
        repository: repo,
        now: () => DateTime(2026, 11, 1, 18, 0),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.crashLogScreen), findsOneWidget);
    expect(find.byKey(AppKeys.crashLogSummary), findsOneWidget);
    expect(find.text('前回の異常終了 2件（最終 12:02）'), findsOneWidget);
    // 新しい順
    expect(find.text('error 2'), findsOneWidget);
    expect(find.text('error 1'), findsOneWidget);
    expect(find.byKey(AppKeys.crashLogEmpty), findsNothing);
  });

  testWidgets('0件なら空状態を出す', (tester) async {
    final repo = InMemoryCrashLogRepository();
    await tester
        .pumpWidget(MaterialApp(home: CrashLogScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.crashLogEmpty), findsOneWidget);
    expect(find.text('記録された不具合はありません'), findsOneWidget);
  });

  testWidgets('コピーボタンでクリップボードへ送る', (tester) async {
    final repo = InMemoryCrashLogRepository([_entry(1)]);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester
        .pumpWidget(MaterialApp(home: CrashLogScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.crashLogCopyButton));
    await tester.pump();

    expect(copied, isNotNull);
    expect(copied, contains('error 1'));
  });

  testWidgets('設定タイルは記録がある時だけ件数を添える', (tester) async {
    final repo = InMemoryCrashLogRepository([_entry(1), _entry(2), _entry(3)]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CrashReportTile(repository: repo)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.crashReportEntryFromSettings), findsOneWidget);
    expect(find.text('不具合の報告 (3)'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.crashReportEntryFromSettings));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.crashLogScreen), findsOneWidget);
  });

  testWidgets('記録が無ければ件数を出さない', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: CrashReportTile(repository: InMemoryCrashLogRepository())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('不具合の報告'), findsOneWidget);
  });
}
