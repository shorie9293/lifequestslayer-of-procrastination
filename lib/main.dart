
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/game_state.dart';
import 'screens/home_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'models/task.dart';
import 'models/player.dart';

void main() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter()); // TypeId: 0
  Hive.registerAdapter(TaskStatusAdapter()); // TypeId: 1
  Hive.registerAdapter(QuestRankAdapter()); // TypeId: 2
  Hive.registerAdapter(PlayerAdapter()); // TypeId: 3

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
      child: MaterialApp(
        title: 'RPG Todo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: const Color(0xFF1a1a2e),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF16213e),
            elevation: 0,
          ),
          textTheme: GoogleFonts.vt323TextTheme(Theme.of(context).textTheme).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          colorScheme: ColorScheme.fromSwatch(
            brightness: Brightness.dark,
            primarySwatch: Colors.deepPurple,
            accentColor: Colors.amber,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
