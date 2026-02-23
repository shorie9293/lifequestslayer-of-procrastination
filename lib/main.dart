import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'viewmodels/game_view_model.dart';
import 'screens/home_screen.dart';
import 'screens/guild_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'models/task.dart';
import 'models/player.dart';

void main() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter()); // TypeId: 0
  Hive.registerAdapter(TaskStatusAdapter()); // TypeId: 1
  Hive.registerAdapter(QuestionRankAdapter()); // TypeId: 2
  Hive.registerAdapter(PlayerAdapter()); // TypeId: 3
  Hive.registerAdapter(JobAdapter()); // TypeId: 4
  Hive.registerAdapter(RepeatIntervalAdapter()); // TypeId: 5
  Hive.registerAdapter(SubTaskAdapter()); // TypeId: 6

  // Boxes are opened in Repositories on demand/init.

  runApp(const RPGTodoApp());
}

class RPGTodoApp extends StatelessWidget {
  const RPGTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameViewModel(),
      child: Consumer<GameViewModel>(
        builder: (context, viewModel, child) {
          return MaterialApp(
            title: 'RPG Todo',
            debugShowCheckedModeBanner: false,
            theme: viewModel.currentTheme.copyWith(
              textTheme: GoogleFonts.vt323TextTheme(viewModel.currentTheme.textTheme).apply(
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
