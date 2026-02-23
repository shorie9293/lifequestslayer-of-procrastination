import 'package:flutter/material.dart';
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

  final List<Widget> _screens = [
    const GuildScreen(),
    const HomeScreen(),
    const TempleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
