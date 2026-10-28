import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/reduce_motion_view_model.dart';
import 'package:rpg_todo/features/shared/data/reduce_motion_repository.dart';
import 'package:rpg_todo/features/shared/domain/reduce_motion_setting.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'package:rpg_todo/features/auth/presentation/auth_gate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_coordinator.dart';
import 'package:rpg_todo/features/reminder/infrastructure/hive_quiet_hours_repository.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';
import 'package:rpg_todo/core/infrastructure/supabase_config.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:app_links/app_links.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_gate.dart';
import 'package:rpg_todo/core/infrastructure/deep_link_service.dart';
import 'package:rpg_todo/core/notification/notification_tap_router.dart';

/// ディープリンクナビゲーションのためのグローバルナビゲーターキー
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 通知タップ → 該当画面遷移の配線（画面対応表は NotificationRoutes と一致）。
final NotificationTapRouter notificationTapRouter = NotificationTapRouter(
  navigatorKey: navigatorKey,
  source: NotificationService(),
);

/// アプリ完全終了状態から起動した場合の初期ディープリンクを保持
Uri? _pendingInitialDeepLink;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // ━━━ Firebase 運用監視基盤（Crashlytics クラッシュ検知 + Analytics KPI計測）━━━
  try {
    await Firebase.initializeApp();
    // Analytics: セッション開始を記録し DAU/定着率のKPI計測を有効化
    unawaited(FirebaseAnalytics.instance.logAppOpen());
    debugPrint('[main] ✅ Firebase 初期化完了');
  } catch (e) {
    // テスト環境や Firebase 未設定時はアプリ起動を妨げず継続する
    debugPrint('[main] ⚠️ Firebase初期化失敗（アプリは継続）: $e');
  }

  // ━━━ Supabase 初期化 ━━━
  const supabaseUrl = SupabaseConfig.url;
  const supabaseKey = SupabaseConfig.anonKey;

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      debugPrint('[main] ✅ Supabase 初期化完了');
      // 匿名サインインは廃止。認証は AuthGate → LoginScreen（Google）で行う。
    } catch (e) {
      debugPrint('[main] ⚠️ Supabase初期化失敗（オフラインモード）: $e');
    }
  } else {
    debugPrint('[main] ⚠️ SUPABASE_URL/SUPABASE_ANON_KEY 未設定（オフラインモード）');
  }

  Hive.registerAdapter(TaskAdapter()); // TypeId: 0
  Hive.registerAdapter(TaskStatusAdapter()); // TypeId: 1
  Hive.registerAdapter(QuestionRankAdapter()); // TypeId: 2
  Hive.registerAdapter(PlayerAdapter()); // TypeId: 3
  Hive.registerAdapter(JobAdapter()); // TypeId: 4
  Hive.registerAdapter(RepeatIntervalAdapter()); // TypeId: 5
  Hive.registerAdapter(SubTaskAdapter()); // TypeId: 6
  Hive.registerAdapter(JobSkillAdapter()); // TypeId: 10
  Hive.registerAdapter(ReflectionAdapter()); // TypeId: 7

  // Boxes are opened in Repositories on demand/init.

  // ━━━ 静穏時間（おやすみモード）box を起動時に開く ━━━
  // 通知スケジューラの既定ガード（QuietHoursGuardWiring）は
  // 「既に open された box を読む」だけなので、ここで開いておかないと
  // 設定画面で保存した静穏時間が通知へ反映されない（設定と本体の分裂）。
  try {
    await Hive.openBox<String>(HiveQuietHoursRepository.boxName);
  } catch (e) {
    debugPrint('[main] ⚠️ 静穏時間 box の初期化に失敗（通知は通常動作）: $e');
  }

  // ━━━ DI 初期化 ━━━
  // configureDependencies() はVMシングルトン登録のみ（データロードはしない）。
  // 実データのロード（initializeViewModels）はGoogleログイン後にAuthGateが行う。
  configureDependencies();

  // IAPサービスの初期化（DI経由）
  try {
    await getIt<IAPService>().initialize();
    debugPrint('[main] IAPサービスの初期化が完了しました');
  } catch (e) {
    debugPrint('[main] IAPサービスの初期化に失敗しました（アプリは継続）: $e');
  }

  // 通知サービスの初期化（エラーが発生してもアプリ起動を妨げない）
  bool notificationInitialized = false;
  try {
    final notificationService = NotificationService();
    // 通知タップの入口を router へ配線してから初期化する
    // （起動前タップは service 側で保留され、初回フレーム後に取り出される）。
    notificationTapRouter.attach();
    await notificationService.initialize(
      onRouteSelected: notificationTapRouter.handleRoute,
    );
    notificationInitialized = true;
    debugPrint('[main] 通知サービスの初期化が完了しました');
  } catch (e) {
    debugPrint('[main] 通知サービスの初期化に失敗しました（アプリは継続）: $e');
  }

  // クイズデータの読み込み（assets/data/knowledge_quests.json）
  try {
    await QuizService.loadQuestions();
    debugPrint(
        '[main] クイズデータの読み込みが完了しました（${QuizService.isLoaded ? (QuizService.drawQuizQuestion() != null ? "読み込み済み" : "空") : "未読み込み"}）');
  } catch (e) {
    debugPrint('[main] クイズデータの読み込みに失敗しました（アプリは継続）: $e');
  }

  // 期限切れ専用クイズデータの読み込み（assets/data/overdue_quests.json）
  try {
    await QuizService.loadOverdueQuestions();
    debugPrint(
        '[main] 期限切れクイズデータの読み込みが完了しました（${QuizService.isOverdueLoaded ? "読み込み済み" : "未読み込み"}）');
  } catch (e) {
    debugPrint('[main] 期限切れクイズデータの読み込みに失敗しました（アプリは継続）: $e');
  }

  // ━━━ コード適応神書 適3：エラー境界 ━━━

  // ① Widgetツリー内の例外を捕捉 → フォールバックUIを表示
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return ErrorBoundaryWidget(
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // ② Flutterフレームワーク内の非同期エラー
  FlutterError.onError = (FlutterErrorDetails details) {
    // クラッシュ検知: 致命的エラーを Crashlytics へ送信（未初期化時はスキップ）
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (e) {
      // Firebase 未初期化（テスト環境等）はスキップ
    }
    FlutterError.presentError(details);
  };

  // ③ ゾーン外の非同期エラー（Platformレベル）
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('💀 捕捉不能エラー: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Firebase 未初期化（テスト環境等）はスキップ
    }
    return true; // true = 処理済み（クラッシュさせない）
  };

  // ━━━ エラー境界 設定完了 ━━━

  // ━━━ アプリ間送客用ディープリンク受信基盤 ━━━
  // app://cross-reward?source=<送客元>&reward=<報酬タイプ>
  final appLinks = AppLinks();

  // 完全終了状態からディープリンクで起動した場合の初期リンクを取得
  try {
    _pendingInitialDeepLink = await appLinks.getInitialLink();
  } catch (e) {
    // ignore: avoid_print
    print('[main] Error getting initial deep link: $e');
  }

  // バックグラウンド→フォアグラウンド復帰時のリンクをリッスン
  appLinks.uriLinkStream.listen(_handleDeepLink);

  runApp(const RPGTodoApp());

  // runApp後に通知スケジュールを設定（実機でハングする可能性があるためrunApp後に移動）
  if (notificationInitialized) {
    Future.microtask(() async {
      try {
        final notificationService = NotificationService();
        await notificationService.scheduleAll();
        debugPrint('[main] 通知スケジュールが完了しました');
        // 締切リマインド（期限間近クエストの通知）を設定に従って反映する。
        // 無効・対象0件なら解除。失敗してもアプリ起動は妨げない。
        final outcome = await DeadlineReminderCoordinator().run();
        debugPrint('[main] 締切リマインドの反映が完了しました: $outcome');
      } catch (e) {
        debugPrint('[main] 通知スケジュールに失敗しました: $e');
      }
    });
  }
}

/// ディープリンクURLを解析し、該当導線に引き渡す。
///
/// 対応URL形式:
///   app://cross-reward?source=<送客元>&reward=<報酬タイプ>
void _handleDeepLink(Uri uri) {
  // ignore: avoid_print
  print('[main] Deep link received: $uri');

  final link = DeepLinkService.parse(uri);
  if (link == null) return;

  // 送客元現世と報酬タイプを記録（受信基盤の具現化）。
  // 報酬付与は既存の FileCrossAppRewardService 等が担うため、ここでは受信を確認する。
  debugPrint('[main] Cross reward: source=${link.source}, reward=${link.reward}');
}

class RPGTodoApp extends StatefulWidget {
  const RPGTodoApp({super.key});

  @override
  State<RPGTodoApp> createState() => _RPGTodoAppState();
}

class _RPGTodoAppState extends State<RPGTodoApp> {
  bool _firstFrameHandled = false;

  @override
  void initState() {
    super.initState();
    // 初回フレーム後に保留中のディープリンクを処理
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  /// 初回フレーム描画後に保留中のディープリンクを処理する。
  ///
  /// アプリ完全終了状態からディープリンクで起動された場合、
  /// [main()] 内ではまだ Navigator が存在しないため、
  /// 初回フレームまで遅延させる必要がある。
  void _onFirstFrame(Duration _) {
    if (_firstFrameHandled) return;
    _firstFrameHandled = true;

    final pendingLink = _pendingInitialDeepLink;
    _pendingInitialDeepLink = null;
    if (pendingLink != null) {
      _handleDeepLink(pendingLink);
    }

    // アプリ起動前にタップされた通知の遷移先を1度だけ取り出して遷移する。
    notificationTapRouter.consumePendingRoute();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 新VM — get_itシングルトンをProviderでラップ
        ChangeNotifierProvider<PlayerViewModel>.value(
            value: getIt<PlayerViewModel>()),
        ChangeNotifierProvider<TaskViewModel>.value(
            value: getIt<TaskViewModel>()),
        ChangeNotifierProvider<ShopViewModel>.value(
            value: getIt<ShopViewModel>()),
        ChangeNotifierProvider<TownViewModel>.value(
            value: getIt<TownViewModel>()),
        ChangeNotifierProvider<SettingsViewModel>.value(
            value: getIt<SettingsViewModel>()),
        ChangeNotifierProvider<ThemeViewModel>.value(
            value: getIt<ThemeViewModel>()),
        // IAPサービス — DI管理
        ChangeNotifierProvider<IAPService>.value(
            value: getIt<IAPService>()),
        // 全VM統括
        ChangeNotifierProvider<GameViewModel>.value(
            value: getIt<GameViewModel>()),
        // 「動きを減らす」設定 — Hive専用boxから復元（端末設定の上書き）
        ChangeNotifierProvider<ReduceMotionViewModel>(
          create: (_) =>
              ReduceMotionViewModel(const HiveReduceMotionRepository())..load(),
        ),
      ],
      child: Consumer2<ThemeViewModel, SettingsViewModel>(
        builder: (context, themeVM, settingsVM, child) {
          return MaterialApp(
            title: 'RPG Todo',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown,
              },
            ),
            theme: themeVM.currentThemeForMode(settingsVM.themeMode).copyWith(
              textTheme: GoogleFonts.dotGothic16TextTheme(
                      themeVM.currentTheme.textTheme)
                  .apply(
                bodyColor:
                    settingsVM.themeMode == ThemeMode.light ? const Color(0xFF2A2520) : Colors.white,
                displayColor:
                    settingsVM.themeMode == ThemeMode.light ? const Color(0xFF2A2520) : Colors.white,
              ),
            ),
            home: AppLockGate(unlockedBuilder: (context) => const AuthGate()),
            builder: (context, child) {
              // 端末設定に従う／アプリ内で上書き（既存の textScaler 挙動は不変）
              final rm = context.watch<ReduceMotionViewModel>().setting;
              final mediaQuery = MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settingsVM.fontSizeScale));
              return MediaQuery(
                data: applyReduceMotion(mediaQuery, rm),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
