import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'viewmodels/game_view_model.dart';
import 'screens/main_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/gestures.dart';
import 'models/task.dart';
import 'models/player.dart';
import 'services/notification_service.dart';
import 'services/iap_service.dart';

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

  // 通知サービスの初期化（エラーが発生してもアプリ起動を妨げない）
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.scheduleAll();
    debugPrint('[main] 通知サービスの初期化が完了しました');
  } catch (e) {
    debugPrint('[main] 通知サービスの初期化に失敗しました（アプリは継続）: $e');
  }

  runApp(const RPGTodoApp());
}

class RPGTodoApp extends StatelessWidget {
  const RPGTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameViewModel()),
        ChangeNotifierProvider(create: (_) => IAPService()..initialize()),
      ],
      child: Consumer<GameViewModel>(
        builder: (context, viewModel, child) {
          return MaterialApp(
            title: 'RPG Todo',
            debugShowCheckedModeBanner: false,
            // PCのマウス操作でもスワイプが反応するように設定（開発・Web用）
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown, // 念のためTrackpadなど含める
              },
            ),
            theme: viewModel.currentTheme.copyWith(
              textTheme: GoogleFonts.dotGothic16TextTheme(viewModel.currentTheme.textTheme).apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            home: const MainScreen(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(viewModel.fontSizeScale)),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
