import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_view_model.dart';
import '../widgets/help_dialog.dart';
import 'guild_screen.dart';
import 'home_screen.dart';
import 'temple_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isHelpDialogShowing = false;

  final List<Widget> _screens = [
    const GuildScreen(),
    const HomeScreen(),
    const TempleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);

    if (!viewModel.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!viewModel.hasSeenConcept && !_isHelpDialogShowing) {
      _isHelpDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showHelpDialog(context).then((_) {
          viewModel.markConceptAsSeen();
        });
      });
    }

    return Scaffold(
      body: _screens[_currentIndex],
      // BottomNavigationBarを追加（Add BottomNavigationBar for smartphones）
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
           setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'ギルド',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '戦場',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.temple_buddhist),
            label: '神殿',
          ),
        ],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black87,
      ),
    );
  }
}
