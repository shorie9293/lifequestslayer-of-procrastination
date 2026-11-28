// 全画面の pump 実装（画面台帳が参照する単一の置き場）。
//
// かつて各 *_light_contrast_test.dart に散在していた「DI モック＋データ＋pump」を
// ここへ集約する。各画面ファイルは台帳キーを呼ぶだけの薄い宣言になる。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/crash/error_boundary.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/account_deletion/domain/account_deletion_service.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_screen.dart';
import 'package:rpg_todo/features/adventurer/data/adventure_share_card_exporter.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card_service.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart_service.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_capture.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventure_share_card_screen.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventurer_chart_screen.dart';
import 'package:rpg_todo/features/auth/presentation/login_screen.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_catalog.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';
import 'package:rpg_todo/features/battle/presentation/enemy_catalog_screen.dart';
import 'package:rpg_todo/features/calendar_export/data/ics_share_exporter.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_screen.dart';
import 'package:rpg_todo/features/calendar_link/data/calendar_gateway.dart';
import 'package:rpg_todo/features/calendar_link/domain/linked_calendar_event.dart';
import 'package:rpg_todo/features/calendar_link/presentation/calendar_import_screen.dart';
import 'package:rpg_todo/features/google_todo/data/google_todo_gateway.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';
import 'package:rpg_todo/features/google_todo/presentation/google_todo_link_screen.dart';
import 'package:rpg_todo/features/guild/data/task_time_record_repository.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_screen.dart';
import 'package:rpg_todo/features/guild/presentation/guild_bulk_action_screen.dart';
import 'package:rpg_todo/features/guild/presentation/quest_streak_screen.dart';
import 'package:rpg_todo/features/guild/data/task_template_repository.dart';
import 'package:rpg_todo/features/guild/domain/task_template.dart';
import 'package:rpg_todo/features/guild/presentation/task_template_screen.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_settings_screen.dart';
import 'package:rpg_todo/features/settings/presentation/reduce_motion_settings_screen.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';
import 'package:rpg_todo/features/about/presentation/about_screen.dart';
import 'package:rpg_todo/core/crash/crash_log_entry.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_screen.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';
import 'package:rpg_todo/features/settings/presentation/cross_app_link_status_screen.dart';
import 'package:rpg_todo/features/reminder/data/deadline_reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/presentation/deadline_reminder_settings_screen.dart';
import 'package:rpg_todo/features/reminder/data/quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:rpg_todo/features/reminder/data/reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/streak_freeze/data/streak_freeze_repository.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';
import 'package:rpg_todo/features/streak_freeze/presentation/streak_freeze_screen.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/presentation/widgets/kozuchi_quest_card.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/features/habits/presentation/widgets/practice_heatmap.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/town/presentation/reflection_badge_collection_screen.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/features/character_customization/presentation/equipment_tab.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_title_encyclopedia_screen.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/overview/presentation/screens/overview_screen.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/bulk_create_task_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/create_task_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/tutorial_reset_dialog.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/town/presentation/town_screen.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rpg_todo/features/project/presentation/project_list_screen.dart';
import 'package:rpg_todo/features/settings/presentation/settings_hub_screen.dart';
import 'package:rpg_todo/features/shared/widgets/debug_panel.dart';
import 'package:rpg_todo/features/habits/presentation/screens/habit_calendar_screen.dart';
import 'package:rpg_todo/features/habits/data/practice_log_repository.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';
import 'package:rpg_todo/features/temple/presentation/pomodoro_timer_screen.dart';
import 'package:rpg_todo/features/shared/data/pomodoro_state_store.dart';
import 'package:rpg_todo/features/town/presentation/gem_shop_screen.dart';
import 'package:rpg_todo/features/battle/presentation/battle_screen.dart';
import 'package:rpg_todo/features/battle/domain/battle_audio_service.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';
import 'package:rpg_todo/screens/main_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/reduce_motion_view_model.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';

import 'contrast_gate.dart';

// ── 町タブ ──────────────────────────────────────────────
Future<void> pumpTownScreen(WidgetTester tester, ThemeData theme) async {
  late GameViewModel vm;
  late PlayerViewModel playerVM;
  late TownViewModel townVM;
  final settings = StdSettingsRepository(fontSizeScale: 0.85);
  await tester.runAsync(() async {
    playerVM =
        PlayerViewModel(StdPlayerRepository(Player(jobLevels: {Job.adventurer: 5})));
    await playerVM.load();
    townVM = TownViewModel();
    townVM.initialize();
    vm = GameViewModel(
      pr: StdPlayerRepository(Player(jobLevels: {Job.adventurer: 5})),
      tr: StdTaskRepository(),
      sr: settings,
      tv: townVM,
    );
    await StdSettingsRepository.waitUntilLoaded(() => vm.isLoaded);
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameViewModel>.value(value: vm),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<ShopViewModel>(create: (_) => ShopViewModel(playerVM)),
        ChangeNotifierProvider<TownViewModel>.value(value: townVM),
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: SettingsViewModel(settings),
        ),
      ],
      child: MaterialApp(theme: theme, home: const TownScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

// ── アカウント削除 ──────────────────────────────────────
Future<void> pumpAccountDeletionScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: AccountDeletionScreen(
        service: AccountDeletionService(signOut: () async {}, clearLocalData: () async {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── 冒険者カルテ ────────────────────────────────────────
Future<void> pumpAdventurerChartScreen(
    WidgetTester tester, ThemeData theme) async {
  final chart = AdventurerChartService.build(Player(
    jobLevels: const {Job.adventurer: 3},
    totalTasksCompleted: 42,
    totalSRankCompleted: 5,
    totalARankCompleted: 3,
    totalBRankCompleted: 10,
    timesWardenDefeated: 1,
    streakDays: 7,
    longestStreak: 14,
    totalReflections: 5,
  ));
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: AdventurerChartScreen(chart: chart)),
  );
  await tester.pumpAndSettle();
}

// ── 冒険の戦績シェアカード ──────────────────────────────
class _FakeShareCapture implements AdventureShareCardCapture {
  @override
  Future<Uint8List?> capture() async => null;
}

class _FakeShareExporter implements AdventureShareCardExporter {
  @override
  Future<void> shareImage({required Uint8List png, required String text}) async {}
}

Future<void> pumpAdventureShareCardScreen(
    WidgetTester tester, ThemeData theme) async {
  final card = AdventureShareCardService.build(Player(
    jobLevels: {Job.adventurer: 9},
    totalTasksCompleted: 42,
    totalSRankCompleted: 5,
    timesWardenDefeated: 7,
    longestStreak: 12,
    totalReflections: 20,
  ));
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: AdventureShareCardScreen(
      card: card,
      exporter: _FakeShareExporter(),
      capture: _FakeShareCapture(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── ログイン ────────────────────────────────────────────
Future<void> pumpLoginScreen(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: LoginScreen(onContinueOffline: () {})),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

// ── ErrorBoundary ───────────────────────────────────────
class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();
  @override
  Widget build(BuildContext context) {
    throw Exception('人工のクラッシュ（コントラスト走査用）');
  }
}

Future<void> pumpErrorBoundary(WidgetTester tester, ThemeData theme) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    errors.add(details);
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: ErrorBoundary(child: _ThrowingWidget())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  FlutterError.onError = previousOnError;
}

// ── 自動バックアップ ────────────────────────────────────
Future<void> pumpAutoBackupScreen(WidgetTester tester, ThemeData theme) async {
  final clock = DateTime(2026, 11, 27, 7);
  final store = InMemoryAutoBackupStore(now: () => clock);
  await store.write(
    'auto_backup_20261127.json',
    jsonEncode({
      'version': 2,
      'exportedAt': '2026-11-26T00:00:00.000Z',
      'player': Player().toJson(),
      'tasks': <dynamic>[],
      'boxes': <String, dynamic>{},
    }),
  );
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: AutoBackupScreen(store: store, now: () => clock),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── 討伐戦績 ────────────────────────────────────────────
BattleRecord _battleRecord(
  String id,
  DateTime at, {
  bool victory = true,
  int combo = 0,
  int remaining = 0,
  String title = 'クエスト',
}) =>
    BattleRecord(
      id: id,
      title: title,
      occurredAt: at,
      isVictory: victory,
      comboCount: combo,
      remainingSubTasks: remaining,
    );

Future<void> pumpBattleRecordScreen(WidgetTester tester, ThemeData theme) async {
  final repo = InMemoryBattleRecordRepository();
  final base = DateTime(2026, 5, 1, 12);
  for (int i = 0; i < 10; i++) {
    await repo.add(_battleRecord(
      'r$i',
      base.add(Duration(hours: i)),
      victory: i % 3 != 0,
      combo: i % 4,
      remaining: i % 3,
      title: 'クエスト${i + 1}',
    ));
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: BattleRecordScreen(repository: repo, now: DateTime(2026, 5, 31, 12)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── 敵図鑑 ──────────────────────────────────────────────
List<EnemyCatalogEntry> _enemyEntries() => [
      EnemyCatalogEntry(
        assetPath: 'assets/sprites/monsters/demons/demon_green_black_armor.png',
        rank: QuestRank.S,
        defeatCount: 3,
        firstDefeatedAt: DateTime(2026, 9, 1, 10),
        lastDefeatedAt: DateTime(2026, 9, 10, 12, 30),
      ),
      EnemyCatalogEntry(
        assetPath: 'assets/sprites/monsters/oni/ogre_green.png',
        rank: QuestRank.A,
        defeatCount: 0,
      ),
      EnemyCatalogEntry(
        assetPath: 'assets/sprites/monsters/oni/oni_red_samurai.png',
        rank: QuestRank.A,
        isRare: true,
        rarityLabel: '歴戦の個体',
        defeatCount: 1,
        firstDefeatedAt: DateTime(2026, 9, 5, 8),
        lastDefeatedAt: DateTime(2026, 9, 5, 8),
      ),
    ];

Future<void> pumpEnemyCatalogScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: EnemyCatalogScreen(entriesOverride: _enemyEntries()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> pumpEnemyCatalogDialog(
    WidgetTester tester, ThemeData theme) async {
  await pumpEnemyCatalogScreen(tester, theme);
  await tester.tap(find.text('歴戦の個体'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// ── カレンダー書き出し ──────────────────────────────────
class _FakeIcsExporter implements IcsShareExporter {
  @override
  Future<void> share({
    required String ics,
    required String fileName,
    required String text,
  }) async {}
}

Future<void> pumpCalendarExportScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: CalendarExportScreen(
      tasksOverride: <Task>[
        Task(id: '1', title: '討伐クエスト', deadline: DateTime(2026, 11, 27)),
        Task(id: '2', title: '薬草集め', deadline: DateTime(2026, 11, 29)),
      ],
      exporter: _FakeIcsExporter(),
      now: DateTime(2026, 11, 27, 9),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── カレンダー取り込み ──────────────────────────────────
class _FakeCalendarGateway implements CalendarGateway {
  @override
  bool get isSupported => true;
  @override
  Future<CalendarAccessStatus> ensureAccess() async =>
      CalendarAccessStatus.granted;
  @override
  Future<List<LinkedCalendarEvent>> readEvents({
    required DateTime from,
    required DateTime to,
  }) async =>
      <LinkedCalendarEvent>[
        LinkedCalendarEvent(
          eventId: 'e1',
          calendarId: 'cal',
          title: '定例MTG',
          start: DateTime(2026, 11, 27, 10),
          end: DateTime(2026, 11, 27, 11),
        ),
      ];
}

Future<void> pumpCalendarImportScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: CalendarImportScreen(
      gateway: _FakeCalendarGateway(),
      tasksOverride: const <Task>[],
      now: DateTime(2026, 11, 27, 8),
      idGenerator: () => 'generated',
    ),
  ));
  await tester.pumpAndSettle();
}

// ── 見積もり精度 ────────────────────────────────────────
Future<void> pumpEstimateAccuracyScreen(
    WidgetTester tester, ThemeData theme) async {
  final records = <TaskTimeRecord>[
    TaskTimeRecord(
        taskId: 'task-1',
        title: 'ゴブリン討伐',
        estimatedMinutes: 100,
        actualMinutes: 100,
        recordedAt: DateTime(2026, 1, 1)),
    TaskTimeRecord(
        taskId: 'task-2',
        title: '薬草採取',
        estimatedMinutes: 100,
        actualMinutes: 150,
        recordedAt: DateTime(2026, 1, 2)),
    TaskTimeRecord(
        taskId: 'task-3',
        title: '書物の写経',
        estimatedMinutes: 100,
        actualMinutes: 60,
        recordedAt: DateTime(2026, 1, 3)),
  ];
  final tasks = <Task>[
    Task(id: 'task-1', title: 'ゴブリン討伐', targetTimeMinutes: 100),
    Task(id: 'task-2', title: '薬草採取', targetTimeMinutes: 30),
  ];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: EstimateAccuracyScreen(
        recordsOverride: records,
        tasksOverride: tasks,
        repository: InMemoryTaskTimeRecordRepository(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── クエスト一括操作 ────────────────────────────────────
Future<void> pumpGuildBulkActionScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: GuildBulkActionScreen(
        tasksOverride: <Task>[
          Task(
              id: 'g1',
              title: 'ゴブリン討伐',
              rank: QuestRank.B,
              status: TaskStatus.inGuild,
              deadline: DateTime(2026, 9, 30)),
          Task(
              id: 'g2',
              title: '薬草採取',
              rank: QuestRank.A,
              status: TaskStatus.inGuild),
          Task(
              id: 'g3',
              title: '書物の写経',
              rank: QuestRank.S,
              status: TaskStatus.inGuild),
          Task(id: 'a1', title: '出発済み', status: TaskStatus.active),
        ],
        applyOverride: (_, __) => 0,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── クエスト別ストリーク ────────────────────────────────
Future<void> pumpQuestStreakScreen(WidgetTester tester, ThemeData theme) async {
  final now = DateTime(2026, 10, 16);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: QuestStreakScreen(
        tasksOverride: [
          Task(id: 't1', title: '魔物討伐'),
          Task(id: 't2', title: '読書'),
          Task(id: 't3', title: '日記'),
        ],
        streaksOverride: {
          't1': TaskStreak(
              currentStreak: 9, lastCompletedDate: DateTime(2026, 10, 16)),
          't2': TaskStreak(
              currentStreak: 3, lastCompletedDate: DateTime(2026, 10, 15)),
        },
        now: now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── 勤行の定型 ──────────────────────────────────────────
Future<void> pumpTaskTemplateScreen(
    WidgetTester tester, ThemeData theme) async {
  final repo = InMemoryTaskTemplateRepository();
  await repo.save([
    TaskTemplate(
        id: 't1',
        name: '朝の支度',
        title: '朝のクエスト',
        rank: QuestRank.S,
        subTaskTitles: const ['洗面', '着替え'],
        targetTimeMinutes: 15),
    TaskTemplate(
        id: 't2', name: '夜の整理', title: '夜のクエスト', rank: QuestRank.A),
    TaskTemplate(
        id: 't3',
        name: '週次の振り返り',
        title: '振り返りクエスト',
        rank: QuestRank.B,
        repeatInterval: RepeatInterval.daily),
  ]);
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: TaskTemplateScreen(repository: repo)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── アプリロック設定 ────────────────────────────────────
Future<void> pumpAppLockSettingsScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: AppLockSettingsScreen(repository: InMemoryAppLockRepository()),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── 動きを減らす設定 ────────────────────────────────────
Future<void> pumpReduceMotionSettingsScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: ReduceMotionSettingsScreen(
        repository: InMemoryReduceMotionRepository(ReduceMotionSetting.on),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── アプリについて ──────────────────────────────────────
Future<void> pumpAboutScreen(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(theme: theme, home: const AboutScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── クラッシュログ ──────────────────────────────────────
CrashLogEntry _crashEntry(int i) => CrashLogEntry(
      timestamp: DateTime(2026, 11, 1, 12, i),
      kind: 'zone',
      message: 'FormatException: テスト用の不具合 $i',
      stackTop: '#0 frame $i',
    );

Future<void> pumpCrashLogScreen(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: CrashLogScreen(
        repository:
            InMemoryCrashLogRepository(<CrashLogEntry>[_crashEntry(1), _crashEntry(2)]),
        now: () => DateTime(2026, 11, 1, 18, 0),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── 連携状況 ────────────────────────────────────────────
Future<void> pumpCrossAppLinkStatusScreen(
    WidgetTester tester, ThemeData theme) async {
  final recorder = CrossAppLinkStatusRecorder(
    store: InMemoryCrossAppLinkStatusStore(),
    now: () => DateTime(2026, 11, 27, 9, 12),
  );
  await recorder.recordFolderReady(true);
  await recorder.recordSent(count: 3, fileName: 'tsundoku_reward_events.jsonl');
  await recorder.recordReceiveFailure(
    StateError('共有フォルダが読めません'),
    fileName: 'kozuchi_quest.json',
  );
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: CrossAppLinkStatusScreen(recorder: recorder)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── 期限リマインダー設定 ────────────────────────────────
class _FakeDeadlineScheduler implements DeadlineReminderScheduler {
  @override
  Future<void> apply(DeadlineReminderSettings s,
      {required String title, required String body}) async {}
  @override
  Future<void> cancel() async {}
}

Future<void> pumpDeadlineReminderSettingsScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: DeadlineReminderSettingsScreen(
      repository: InMemoryDeadlineReminderRepository(),
      scheduler: _FakeDeadlineScheduler(),
      tasksOverride: <Task>[
        Task(id: 'a', title: '薬草集め', deadline: DateTime(2026, 11, 27, 23)),
        Task(id: 'b', title: '洞窟探索', deadline: DateTime(2026, 11, 29, 12)),
      ],
      now: DateTime(2026, 11, 27, 9),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── 静穏時間設定 ────────────────────────────────────────
Future<void> pumpQuietHoursSettingsScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: QuietHoursSettingsScreen(
      repository: InMemoryQuietHoursRepository(),
      now: DateTime(2026, 11, 27, 12),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── 勤行リマインダー設定 ────────────────────────────────
class _NoopReminderScheduler implements ReminderScheduler {
  @override
  Future<void> apply(ReminderSettings s) async {}
  @override
  Future<void> cancel() async {}
}

Future<void> pumpReminderSettingsScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: ReminderSettingsScreen(
      repository: InMemoryReminderRepository(),
      scheduler: _NoopReminderScheduler(),
      now: DateTime(2026, 11, 27, 9),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── お休み券（連続記録フリーズ） ──────────────────────────
class _MutablePlayerRepository implements IPlayerRepository {
  _MutablePlayerRepository(this._player);
  Player? _player;
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

PlayerViewModel _brokenStreakVm() {
  final player = Player(
    streakDays: 12,
    longestStreak: 20,
    lastLoginDate: DateTime(2026, 10, 18, 9),
  );
  final vm = PlayerViewModel(_MutablePlayerRepository(player));
  vm.player = player;
  vm.checkAndResetMissions(DateTime(2026, 10, 20, 9), login: true);
  return vm;
}

Future<void> _pumpStreakFreeze(
  WidgetTester tester,
  ThemeData theme, {
  required int tickets,
  required bool withHistory,
}) async {
  final state = StreakFreezeState(
    tickets: tickets,
    history: withHistory
        ? [
            StreakFreezeUsage(
              usedAt: DateTime(2026, 10, 5, 21, 30),
              coveredMissedDays: 1,
              keptStreak: 14,
            ),
          ]
        : const [],
  );
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: StreakFreezeScreen(
      repository: InMemoryStreakFreezeRepository(state),
      playerViewModel: _brokenStreakVm(),
      clock: () => DateTime(2026, 10, 20, 9),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> pumpStreakFreezeRich(WidgetTester tester, ThemeData theme) =>
    _pumpStreakFreeze(tester, theme, tickets: 2, withHistory: true);

Future<void> pumpStreakFreezeSparse(WidgetTester tester, ThemeData theme) =>
    _pumpStreakFreeze(tester, theme, tickets: 0, withHistory: false);

// ── KozuchiQuestCard ────────────────────────────────────
KozuchiQuest _kozuchiQuest({bool isCompleted = false}) => KozuchiQuest(
      title: '英気を養う読書の時間',
      description: '毎日15分、好きな本を読んで心を豊かにする試練です。スマホを脇に置いて集中しましょう。',
      suggestedOffering: 500,
      advisorEmoji: '🪘',
      advisorLabel: 'ライフプランナー',
      isCompleted: isCompleted,
    );

Future<void> _pumpKozuchi(
    WidgetTester tester, ThemeData theme, KozuchiQuest quest) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: KozuchiQuestCard(quest: quest))),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> pumpKozuchiQuestCard(WidgetTester tester, ThemeData theme) =>
    _pumpKozuchi(tester, theme, _kozuchiQuest());

Future<void> pumpKozuchiQuestCardDone(WidgetTester tester, ThemeData theme) =>
    _pumpKozuchi(tester, theme, _kozuchiQuest(isCompleted: true));

// ── 勤行ヒートマップ ────────────────────────────────────
List<PracticeLog> _heatmapLogs() => [
      for (var i = 0; i < 12; i++)
        PracticeLog(
          date: DateTime(2026, 6, 1 + i),
          count: 1 + i % 4,
          updatedAt: DateTime(2026, 6, 1 + i, (i * 2 + 3) % 24),
        ),
    ];

Future<void> _pumpHeatmap(
    WidgetTester tester, ThemeData theme, List<PracticeLog> logs) async {
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: Scaffold(body: PracticeHeatmapView(logs: logs))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> pumpPracticeHeatmap(WidgetTester tester, ThemeData theme) =>
    _pumpHeatmap(tester, theme, _heatmapLogs());

Future<void> pumpPracticeHeatmapEmpty(WidgetTester tester, ThemeData theme) =>
    _pumpHeatmap(tester, theme, const []);

// ── 内省バッジ一覧 ──────────────────────────────────────
class _FakeReflectionRepository implements ReflectionRepository {
  _FakeReflectionRepository(this.reflections);
  final List<Reflection> reflections;
  @override
  Future<List<Reflection>> getAll() async => reflections;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Reflection _seedReflection(DateTime date, {int self = 1, QuestRank ai = QuestRank.B}) =>
    Reflection(
      id: 'r_${date.millisecondsSinceEpoch}_${self}_$ai',
      taskId: 't1',
      date: date,
      content: '学び',
      selfDifficulty: self,
      aiDifficulty: ai,
    );

List<Reflection> _seedReflections() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 14; i++)
      _seedReflection(now.subtract(Duration(days: i)),
          self: (i % 5) + 1, ai: QuestRank.values[i % QuestRank.values.length]),
  ];
}

Future<void> pumpReflectionBadgeCollectionScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: ReflectionBadgeCollectionScreen(
        repository: _FakeReflectionRepository(_seedReflections()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── 装備タブ ────────────────────────────────────────────
Future<void> _pumpEquipment(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: EquipmentTab(
          currentSkin: const CharacterSkin(),
          playerLevel: 50,
          streakDays: 30,
          totalTasks: 100,
          titles: const ['伝説の討伐者'],
          onEquip: (_, __) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> pumpEquipmentInitial(WidgetTester tester, ThemeData theme) =>
    _pumpEquipment(tester, theme);

Future<void> pumpEquipmentList(WidgetTester tester, ThemeData theme) async {
  await _pumpEquipment(tester, theme);
  await tester.tap(find.text('鎧'), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> pumpEquipmentPreview(WidgetTester tester, ThemeData theme) async {
  await _pumpEquipment(tester, theme);
  await tester.tap(find.text('鎧'), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(find.text('王家の鎧'), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
}

// ── クエスト検索 ────────────────────────────────────────
final DateTime _questSearchNow = DateTime(2026, 9, 22, 12, 0, 0);

Task _questTask(
  String id,
  String title, {
  QuestRank rank = QuestRank.B,
  DateTime? deadline,
  int? targetTimeMinutes,
  List<String> tags = const [],
}) =>
    Task(
      id: id,
      title: title,
      rank: rank,
      deadline: deadline,
      targetTimeMinutes: targetTimeMinutes,
      tags: tags,
    );

List<Task> _questSearchTasks() => [
      _questTask('t01', 'ゴブリン討伐',
          deadline: _questSearchNow.add(const Duration(days: 1)),
          targetTimeMinutes: 30,
          tags: ['戦闘']),
      _questTask('t02', 'ドラゴン討伐',
          rank: QuestRank.S,
          deadline: _questSearchNow.add(const Duration(days: 7)),
          targetTimeMinutes: 600,
          tags: ['戦闘', '冒険']),
      _questTask('t03', '薬草採取',
          rank: QuestRank.A, targetTimeMinutes: 120, tags: ['採集']),
      _questTask('t04', '書物の写経', targetTimeMinutes: 90, tags: ['学問']),
      _questTask('t05', '村の見回り', rank: QuestRank.A),
      _questTask('t06', 'ガレージ掃除',
          deadline: _questSearchNow.subtract(const Duration(days: 2))),
      _questTask('t07', '報告書作成', targetTimeMinutes: 60),
      _questTask('t08', '剣術の修行', rank: QuestRank.S, targetTimeMinutes: 300),
      _questTask('t09', '井戸の清掃', rank: QuestRank.A, targetTimeMinutes: 45),
      _questTask('t10', '手紙の配達', targetTimeMinutes: 15),
      _questTask('t11', '期限切れの納税',
          rank: QuestRank.A,
          deadline: _questSearchNow.subtract(const Duration(hours: 1))),
      _questTask('t12', '境界の同時刻クエスト', deadline: _questSearchNow),
    ];

Future<void> pumpGuildQuestSearchScreen(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: GuildQuestSearchScreen(
          tasksOverride: _questSearchTasks(), now: _questSearchNow),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── クロスアプリ称号図鑑 ────────────────────────────────
Future<void> pumpCrossAppTitleEncyclopedia(
    WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const CrossAppTitleEncyclopediaScreen(
        ownedTitles: ['読書家の卵', '知識の探求者'],
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

// ── 俯瞰の魔眼 ──────────────────────────────────────────
class _OverviewPlayerRepo implements IPlayerRepository {
  _OverviewPlayerRepo(this._player);
  final Player _player;
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class _OverviewTaskRepo implements ITaskRepository {
  _OverviewTaskRepo(this._tasks);
  final List<Task> _tasks;
  @override
  Future<List<Task>> loadTasks() async => _tasks;
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

List<Task> _overviewTasks() => [
      Task(
          id: 't1',
          title: '期限付きクエストA',
          deadline: DateTime(2026, 6, 1),
          rank: QuestRank.S),
      Task(
          id: 't2',
          title: '期限付きクエストB',
          deadline: DateTime(2026, 6, 1),
          rank: QuestRank.A,
          isCompleted: true),
      Task(
          id: 't3',
          title: '期限なしクエスト',
          status: TaskStatus.active,
          rank: QuestRank.B),
      Task(id: 't4', title: '現役クエスト', status: TaskStatus.active),
      Task(id: 't5', title: '掲示板クエスト', status: TaskStatus.inGuild),
      Task(id: 't6', title: '期限付きクエストC', deadline: DateTime(2026, 6, 2)),
    ];

Future<void> _pumpOverview(
  WidgetTester tester,
  ThemeData theme, {
  required bool unlocked,
  required bool kanban,
}) async {
  final player = Player(
    currentJob: Job.mystic,
    jobLevels: {Job.mystic: unlocked ? 15 : 1},
  );
  final playerVM = PlayerViewModel(_OverviewPlayerRepo(player));
  await playerVM.load();
  final taskVM = TaskViewModel(_OverviewTaskRepo(_overviewTasks()), playerVM);
  await taskVM.load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
      ],
      child: MaterialApp(theme: theme, home: const OverviewScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  if (kanban) {
    await tester.tap(find.text('カンバン'));
    await tester.pumpAndSettle();
  }
}

Future<void> pumpOverviewCalendar(WidgetTester tester, ThemeData theme) =>
    _pumpOverview(tester, theme, unlocked: true, kanban: false);

Future<void> pumpOverviewKanban(WidgetTester tester, ThemeData theme) =>
    _pumpOverview(tester, theme, unlocked: true, kanban: true);

Future<void> pumpOverviewLocked(WidgetTester tester, ThemeData theme) =>
    _pumpOverview(tester, theme, unlocked: false, kanban: false);

// ── 寄合所（guild_screen / 各ダイアログ）で共用する DI モック ──
class GuildPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => Player(jobLevels: {Job.adventurer: 5});
  @override
  Future<void> savePlayer(Player player) async {}
  @override
  Future<void> close() async {}
}

class GuildTaskRepo implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

class GuildSettingsRepo extends SettingsRepository {
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<void> setFontSizeScale(double scale) async {}
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<void> setKnowledgeQuestEnabled(bool enabled) async {}
  @override
  Future<void> saveFatiguePopupDate(DateTime date) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<void> setTutorialStep(int step) async {}
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<void> setHasSeenConcept(bool value) async {}
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<void> setTutorialSkipped(bool value) async {}
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<void> setTutorialChoiceMade(bool value) async {}
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setJobTutorialCompleted(bool value) async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
  @override
  Future<bool> getSfxEnabled() async => true;
  @override
  Future<double> getSfxVolume() async => 0.7;
  @override
  Future<void> setSfxVolume(double volume) async {}
  @override
  Future<void> setSfxEnabled(bool enabled) async {}
  @override
  Future<bool> getBattleSceneEnabled() async => true;
  @override
  Future<void> setBattleSceneEnabled(bool enabled) async {}
  @override
  Future<DateTime?> getLastBackupTime() async => null;
  @override
  Future<void> setLastBackupTime(DateTime time) async {}
}

Future<void> _pumpGuild(WidgetTester tester, ThemeData theme,
    {required bool expand}) async {
  final playerVM = PlayerViewModel(GuildPlayerRepo());
  final taskVM = TaskViewModel(GuildTaskRepo(), playerVM);
  final settingsVM = SettingsViewModel(GuildSettingsRepo());
  await tester.runAsync(() async {
    await playerVM.load();
    taskVM.addTask('古文書の写経', rank: QuestRank.B, targetTimeMinutes: 30);
    taskVM.addTask('剣術の稽古', rank: QuestRank.A, targetTimeMinutes: 45);
    taskVM.addTask('薬草の採集', rank: QuestRank.S);
    taskVM.addTask('魔獣の討伐',
        rank: QuestRank.A,
        deadline: DateTime.now().add(const Duration(hours: 3)));
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
      ],
      child: MaterialApp(theme: theme, home: const GuildScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  if (expand) {
    // 寄合所は既定で全ての束を畳む（2026-11-28）。畳んだままでは TaskCard が
    // 存在せず走査母数が空振りになるため、まず全開ボタンで開く。
    final toggle = find.byKey(AppKeys.guildToggleAllGroups);
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
    final count = find.byType(TaskCard).evaluate().length;
    for (var i = 0; i < count; i++) {
      await tester.tap(find.byType(TaskCard).at(i), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
  }
}

Future<void> pumpGuildScreen(WidgetTester tester, ThemeData theme) =>
    _pumpGuild(tester, theme, expand: false);

Future<void> pumpGuildScreenExpanded(WidgetTester tester, ThemeData theme) =>
    _pumpGuild(tester, theme, expand: true);

Future<void> _pumpGuildDialog(
  WidgetTester tester,
  ThemeData theme,
  Widget dialog,
) async {
  final playerVM = PlayerViewModel(GuildPlayerRepo());
  final taskVM = TaskViewModel(GuildTaskRepo(), playerVM);
  final settingsVM = SettingsViewModel(GuildSettingsRepo());
  final gameVM = GameViewModel(
    pr: GuildPlayerRepo(),
    tr: GuildTaskRepo(),
    sr: GuildSettingsRepo(),
  );
  await tester.runAsync(() async {
    await playerVM.load();
    while (!gameVM.isLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
        ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => dialog,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> pumpCreateTaskDialog(WidgetTester tester, ThemeData theme) =>
    _pumpGuildDialog(tester, theme, const CreateTaskDialog());

Future<void> pumpBulkCreateTaskDialog(WidgetTester tester, ThemeData theme) =>
    _pumpGuildDialog(tester, theme, const BulkCreateTaskDialog());

Future<void> pumpTutorialResetDialog(WidgetTester tester, ThemeData theme) =>
    _pumpGuildDialog(tester, theme, const TutorialResetDialog());

// ── 計画の陣（プロジェクト一覧） ──────────────────────────
Player _projectPlayer({required bool unlocked}) => Player(
      currentJob: Job.mystic,
      jobLevels: {Job.mystic: unlocked ? 12 : 1},
      projects: unlocked
          ? [
              ProjectGroup(name: '計画P', taskIds: ['t1', 't2'], bonusExp: 50),
              ProjectGroup(name: '計画Q', taskIds: ['t3'], bonusExp: 10),
            ]
          : null,
      taskProjects:
          unlocked ? {'t1': '計画P', 't2': '計画P', 't3': '計画Q'} : null,
    );

List<Task> _projectTasks() => [
      Task(id: 't1', title: 'クエストt1', isCompleted: true),
      Task(id: 't2', title: 'クエストt2'),
      Task(id: 't3', title: 'クエストt3', isCompleted: true),
    ];

Future<void> _pumpProjectList(
  WidgetTester tester,
  ThemeData theme, {
  required Player player,
  required List<Task> tasks,
}) async {
  final vm = PlayerViewModel(StdPlayerRepository(player));
  await vm.load();
  vm.player = player;
  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(
        theme: theme,
        home: ProjectListScreen(tasksOverride: tasks),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> pumpProjectListScreenUnlocked(WidgetTester tester, ThemeData theme) =>
    _pumpProjectList(tester, theme,
        player: _projectPlayer(unlocked: true), tasks: _projectTasks());

Future<void> pumpProjectListScreenEmpty(WidgetTester tester, ThemeData theme) =>
    _pumpProjectList(tester, theme,
        player: Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 12}),
        tasks: const []);

Future<void> pumpProjectListScreenLocked(WidgetTester tester, ThemeData theme) =>
    _pumpProjectList(tester, theme,
        player: _projectPlayer(unlocked: false), tasks: _projectTasks());

// ── 設定ハブ ────────────────────────────────────────────
Future<void> pumpSettingsHubScreen(WidgetTester tester, ThemeData theme) async {
  final vm = SettingsViewModel(StdSettingsRepository(fontSizeScale: 0.85));
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsViewModel>.value(
      value: vm,
      child: MaterialApp(theme: theme, home: const SettingsHubScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── DebugPanel ──────────────────────────────────────────
Future<void> pumpDebugPanel(WidgetTester tester, ThemeData theme) async {
  final playerVM = PlayerViewModel(
      StdPlayerRepository(Player(coins: 100, gems: 5, jobLevels: {Job.adventurer: 5})));
  final taskVM = TaskViewModel(StdTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(StdSettingsRepository(
    fontSizeScale: 0.85,
    debugModeEnabled: true,
    sfxEnabled: true,
    battleSceneEnabled: true,
  ));
  await tester.runAsync(() async {
    await playerVM.load();
    await settingsVM.load();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(body: DebugPanel(settingsVM: settingsVM)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

// ── 勤行の習慣カレンダー ────────────────────────────────
class _FakePracticeLogRepository extends PracticeLogRepository {
  _FakePracticeLogRepository(this.logs);
  final List<PracticeLog> logs;
  @override
  Future<List<PracticeLog>> getAll() async => logs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final DateTime _habitNow = DateTime(2026, 9, 15, 12);

Reflection _habitReflection(DateTime date) => Reflection(
      id: 'r_${date.millisecondsSinceEpoch}',
      taskId: 't1',
      date: date,
      content: 'content',
      selfDifficulty: 3,
      aiDifficulty: QuestRank.A,
      sentiment: 'kaishin',
    );

Future<void> _pumpHabitCalendar(WidgetTester tester, ThemeData theme,
    {required bool withData}) async {
  final logs = withData
      ? <PracticeLog>[
          PracticeLog(date: DateTime(2026, 9, 1), count: 2),
          PracticeLog(date: DateTime(2026, 9, 8), count: 1),
          PracticeLog(date: DateTime(2026, 9, 14), count: 3),
          PracticeLog(date: DateTime(2026, 9, 15), count: 1),
        ]
      : const <PracticeLog>[];
  final reflections = withData
      ? <Reflection>[
          _habitReflection(DateTime(2026, 9, 14)),
          _habitReflection(DateTime(2026, 9, 15)),
        ]
      : const <Reflection>[];
  final taskVM = TaskViewModel(
    StdTaskRepository([
      Task(id: 't1', title: 'quest', lastCompletedAt: DateTime(2026, 9, 15)),
    ]),
    PlayerViewModel(StdPlayerRepository()),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<TaskViewModel>.value(
      value: taskVM,
      child: MaterialApp(
        theme: theme,
        home: HabitCalendarScreen(
          repository: _FakeReflectionRepository(reflections),
          practiceLogRepository: _FakePracticeLogRepository(logs),
          now: _habitNow,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> pumpHabitCalendarScreen(WidgetTester tester, ThemeData theme) =>
    _pumpHabitCalendar(tester, theme, withData: true);

Future<void> pumpHabitCalendarScreenEmpty(WidgetTester tester, ThemeData theme) =>
    _pumpHabitCalendar(tester, theme, withData: false);

// ── 寺院・ポモドーロ ────────────────────────────────────
Player _templeRichPlayer() => Player(jobLevels: {
      Job.adventurer: 12,
      Job.samurai: 10,
      Job.monk: 6,
      Job.mystic: 3,
    });

Future<void> pumpTempleScreen(WidgetTester tester, ThemeData theme) async {
  final vm = PlayerViewModel(StdPlayerRepository(_templeRichPlayer()));
  await tester.runAsync(() async {
    await vm.load();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(theme: theme, home: const TempleScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpPomodoro(WidgetTester tester, ThemeData theme,
    {required Player player}) async {
  final vm = PlayerViewModel(StdPlayerRepository(player));
  await tester.runAsync(() async {
    await vm.load();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<PlayerViewModel>.value(
      value: vm,
      child: MaterialApp(
        theme: theme,
        home: PomodoroTimerScreen(
          store: InMemoryPomodoroStateStore(),
          now: () => DateTime(2026, 11, 20, 9),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> pumpPomodoroScreen(WidgetTester tester, ThemeData theme) =>
    _pumpPomodoro(tester, theme, player: _templeRichPlayer());

Future<void> pumpPomodoroScreenSimple(WidgetTester tester, ThemeData theme) =>
    _pumpPomodoro(tester, theme,
        player: Player(jobLevels: {Job.adventurer: 5, Job.samurai: 10}));

// ── 宝石ショップ ────────────────────────────────────────
class _MockIAPService extends IAPService {
  static final List<ProductDetails> _products = [
    ProductDetails(
      id: 'gems_tier1',
      title: '100 gems',
      description: '100 gems',
      price: '¥160',
      rawPrice: 160,
      currencyCode: 'JPY',
    ),
    ProductDetails(
      id: 'gems_tier2',
      title: '550 gems',
      description: '550 gems',
      price: '¥800',
      rawPrice: 800,
      currencyCode: 'JPY',
    ),
    ProductDetails(
      id: 'gems_tier3',
      title: '1200 gems',
      description: '1200 gems',
      price: '¥1,600',
      rawPrice: 1600,
      currencyCode: 'JPY',
    ),
    ProductDetails(
      id: 'gems_tier4',
      title: '2600 gems',
      description: '2600 gems',
      price: '¥3,200',
      rawPrice: 3200,
      currencyCode: 'JPY',
    ),
  ];

  @override
  bool get available => true;
  @override
  bool get loading => false;
  @override
  List<ProductDetails> get products => _products;
  @override
  String? get errorMessage => null;
  @override
  Future<int> consumePendingGems() async => 0;
  @override
  void clearError() {}
}

Future<void> pumpGemShopScreen(WidgetTester tester, ThemeData theme) async {
  final playerVM =
      PlayerViewModel(StdPlayerRepository(Player(coins: 5000, gems: 120)));
  await playerVM.load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<ShopViewModel>(
            create: (_) => ShopViewModel(playerVM)),
        ChangeNotifierProvider<IAPService>.value(value: _MockIAPService()),
      ],
      child: MaterialApp(theme: theme, home: const GemShopScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

// ── 戦闘画面・メイン画面（getIt 経由） ──────────────────
class _ContrastAudio extends BattleAudioService {
  @override
  bool get sfxEnabled => false;
  @override
  void setSfxEnabled(bool enabled) {}
  @override
  Future<void> playVictory() async {}
  @override
  Future<void> playDefeat() async {}
}

/// 戦闘・メイン画面が getIt から引く BattleViewModel / BattleAudioService を登録する。
void registerBattleServices() {
  if (getIt.isRegistered<BattleViewModel>()) {
    getIt.unregister<BattleViewModel>();
  }
  if (getIt.isRegistered<BattleAudioService>()) {
    getIt.unregister<BattleAudioService>();
  }
  getIt.registerLazySingleton<BattleViewModel>(() => BattleViewModel());
  getIt.registerLazySingleton<BattleAudioService>(() => _ContrastAudio());
}

/// 戦闘画面の共通セットアップ（一覧・戦術選択で共有）。
Future<void> _pumpBattle(
  WidgetTester tester,
  ThemeData theme, {
  required bool combat,
}) async {
  final playerVM = PlayerViewModel(StdPlayerRepository());
  final taskVM = TaskViewModel(StdTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(StdSettingsRepository(
    sfxEnabled: false,
    battleSceneEnabled: true,
  ));
  await tester.runAsync(() async {
    await playerVM.load();
    playerVM.player.jobLevels[playerVM.player.currentJob] = 5;
    if (combat) {
      taskVM.addTask('古文書の解読', rank: QuestRank.B, targetTimeMinutes: 30);
    } else {
      taskVM.addTask('古文書の解読', rank: QuestRank.B, targetTimeMinutes: 30);
      taskVM.addTask('剣術の稽古', rank: QuestRank.A, targetTimeMinutes: 45);
      taskVM.addTask('薬草集め', rank: QuestRank.B, targetTimeMinutes: 15);
    }
    for (final t in List<Task>.from(taskVM.tasks)) {
      taskVM.acceptTask(t.id);
    }
    await settingsVM.load();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
        ChangeNotifierProvider<GameViewModel>.value(
          value: GameViewModel(
            playerVM: playerVM,
            taskVM: taskVM,
            settingsVM: settingsVM,
            autoLoad: false,
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: BattleScreen(
          battleRecordRepository: InMemoryBattleRecordRepository(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  if (combat) {
    await tester.tap(find.text('[B] 古文書の解読'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('討つ！'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> pumpBattleScreen(WidgetTester tester, ThemeData theme) =>
    _pumpBattle(tester, theme, combat: false);

Future<void> pumpBattleScreenCombat(WidgetTester tester, ThemeData theme) =>
    _pumpBattle(tester, theme, combat: true);

class _StubReduceMotionRepository implements ReduceMotionRepository {
  @override
  Future<ReduceMotionSetting?> load() async => null;
  @override
  Future<void> save(ReduceMotionSetting setting) async {}
}

Future<void> pumpMainScreen(WidgetTester tester, ThemeData theme) async {
  final playerVM = PlayerViewModel(
      StdPlayerRepository(Player(jobLevels: {Job.adventurer: 5})));
  final taskVM = TaskViewModel(StdTaskRepository(), playerVM);
  final settingsVM = SettingsViewModel(StdSettingsRepository(
    tutorialStep: 3,
    hasSeenConcept: true,
    tutorialChoiceMade: true,
    jobTutorialCompleted: true,
    sfxEnabled: false,
  ));
  final shopVM = ShopViewModel(playerVM);
  final townVM = TownViewModel();
  final gameVM = GameViewModel(
    playerVM: playerVM,
    taskVM: taskVM,
    shopVM: shopVM,
    settingsVM: settingsVM,
    autoLoad: false,
  );
  await tester.runAsync(() async {
    await playerVM.load();
    await taskVM.load();
    await settingsVM.load();
    townVM.initialize();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
        ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
        ChangeNotifierProvider<ShopViewModel>.value(value: shopVM),
        ChangeNotifierProvider<TownViewModel>.value(value: townVM),
        ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
        ChangeNotifierProvider<ReduceMotionViewModel>(
            create: (_) => ReduceMotionViewModel(_StubReduceMotionRepository())),
      ],
      child: MaterialApp(
        theme: theme,
        home: MainScreen(offline: true, onExitOffline: () {}),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// オフラインバナーをタップして復帰ダイアログを開く。
Future<void> openMainOfflineDialog(WidgetTester tester) async {
  await tester.tap(find.text('オフライン'), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// ── Google ToDo 連携 ────────────────────────────────────
/// 通信を持たないフェイク（既存の画面試練と同じ 6 メソッド）。
class _FakeGoogleTodoGateway implements GoogleTodoGateway {
  _FakeGoogleTodoGateway(this.status);

  GoogleTodoStatus status;

  @override
  Future<GoogleTodoStatus> fetchStatus() async => status;

  @override
  Future<String> startLink() async =>
      'https://accounts.google.com/o/oauth2/v2/auth?state=contrast';

  @override
  Future<List<GoogleTodoList>> fetchLists() async => const <GoogleTodoList>[
        GoogleTodoList(id: '@default', title: 'マイタスク'),
        GoogleTodoList(id: 'list-2', title: '仕事'),
      ];

  @override
  Future<void> selectList({required String id, String? title}) async {
    status = GoogleTodoStatus(
      linked: true,
      email: status.email,
      listId: id,
      listTitle: title,
    );
  }

  @override
  Future<void> unlink() async {
    status = GoogleTodoStatus.notLinked;
  }

  @override
  Future<GoogleTodoSyncResult> sync() async =>
      const GoogleTodoSyncResult(pulled: 1, pushed: 2);
}

/// 連携済み状態（本文量が最も多い）を描画する。ローディング完了まで pump する。
Future<void> pumpGoogleTodoLinkScreen(
    WidgetTester tester, ThemeData theme) async {
  final gateway = _FakeGoogleTodoGateway(
    GoogleTodoStatus(
      linked: true,
      email: 'horie.shunta@gmail.com',
      listId: '@default',
      listTitle: 'マイタスク',
      lastOkAt: DateTime.utc(2026, 11, 20, 1, 0),
      pulled: 2,
      pushed: 1,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: GoogleTodoLinkScreen(
        gateway: gateway,
        clock: () => DateTime.utc(2026, 11, 20, 1, 5),
      ),
    ),
  );
  // CircularProgressIndicator が回り続けるため pumpAndSettle は使わない。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
