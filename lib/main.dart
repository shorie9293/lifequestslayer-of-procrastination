
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/game_state.dart';
import 'screens/home_screen.dart';
import 'screens/guild_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'models/task.dart';
import 'models/player.dart';

void main() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter()); // TypeId: 0
  Hive.registerAdapter(TaskStatusAdapter()); // TypeId: 1
  Hive.registerAdapter(QuestionRankAdapter()); // TypeId: 2 (Renamed in task.dart, matching class name)
  Hive.registerAdapter(PlayerAdapter()); // TypeId: 3
  Hive.registerAdapter(JobAdapter()); // TypeId: 4
  Hive.registerAdapter(RepeatIntervalAdapter()); // TypeId: 5
  Hive.registerAdapter(SubTaskAdapter()); // TypeId: 6

  await Hive.openBox<Task>('tasksBox');
  await Hive.openBox<Player>('playerBox');

  runApp(const RPGTodoApp());
}

class RPGTodoApp extends StatelessWidget {
  const RPGTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameState(),
      child: Consumer<GameState>(
        builder: (context, gameState, child) {
          return MaterialApp(
            title: 'RPG Todo',
            debugShowCheckedModeBanner: false,
            theme: gameState.currentTheme.copyWith(
              // Ensure text theme is applied to the new theme
              textTheme: GoogleFonts.vt323TextTheme(gameState.currentTheme.textTheme).apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            home: const GuildScreen(),
          );
        },
      ),
    );
  }
}
