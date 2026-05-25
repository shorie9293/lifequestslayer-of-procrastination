import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/core/di/injection.dart';
import 'screens/main_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/core/infrastructure/notification_service.dart';
import 'package:rpg_todo/core/infrastructure/iap_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter()); // TypeId: 0
  Hive.registerAdapter(TaskStatusAdapter()); // TypeId: 1
  Hive.registerAdapter(QuestionRankAdapter()); // TypeId: 2
  Hive.registerAdapter(PlayerAdapter()); // TypeId: 3
  Hive.registerAdapter(JobAdapter()); // TypeId: 4
  Hive.registerAdapter(RepeatIntervalAdapter()); // TypeId: 5
  Hive.registerAdapter(SubTaskAdapter()); // TypeId: 6

  // Boxes are opened in Repositories on demand/init.

  // ━━━ DI 初期化 ━━━
  configureDependencies();

  // 通知サービスの初期化（エラーが発生してもアプリ起動を妨げない）
  bool notificationInitialized = false;
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
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
    FlutterError.presentError(details);
    // TODO: ログ送信（天神社ステージで実装）
  };

  // ③ ゾーン外の非同期エラー（Platformレベル）
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('💀 捕捉不能エラー: $error\n$stack');
    return true; // true = 処理済み（クラッシュさせない）
  };

  // ━━━ エラー境界 設定完了 ━━━

  runApp(const RPGTodoApp());

  // runApp後に通知スケジュールを設定（実機でハングする可能性があるためrunApp後に移動）
  if (notificationInitialized) {
    Future.microtask(() async {
      try {
        final notificationService = NotificationService();
        await notificationService.scheduleAll();
        debugPrint('[main] 通知スケジュールが完了しました');
      } catch (e) {
        debugPrint('[main] 通知スケジュールに失敗しました: $e');
      }
    });
  }
}

class RPGTodoApp extends StatelessWidget {
  const RPGTodoApp({super.key});

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
        ChangeNotifierProvider<SettingsViewModel>.value(
            value: getIt<SettingsViewModel>()),
        ChangeNotifierProvider<ThemeViewModel>.value(
            value: getIt<ThemeViewModel>()),
        // 旧VM — 後方互換のため当面維持
        ChangeNotifierProvider(create: (_) => GameViewModel()),
        ChangeNotifierProvider(create: (_) => IAPService()..initialize()),
      ],
      child: Consumer2<ThemeViewModel, SettingsViewModel>(
        builder: (context, themeVM, settingsVM, child) {
          return MaterialApp(
            title: 'RPG Todo',
            debugShowCheckedModeBanner: false,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown,
              },
            ),
            theme: themeVM.currentTheme.copyWith(
              textTheme: GoogleFonts.dotGothic16TextTheme(
                      themeVM.currentTheme.textTheme)
                  .apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            home: const MainScreen(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(settingsVM.fontSizeScale)),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
