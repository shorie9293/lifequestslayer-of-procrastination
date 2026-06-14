import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SemanticHelper.navigation(
      testId: SemanticHelper.createTestId(
          SemanticTypes.navigation, 'bottom_tab_bar'),
      label: '画面切替',
      child: BottomNavigationBar(
        key: AppKeys.tabBar,
        currentIndex: currentIndex,
        onTap: onTabChanged,
        items: const [
          BottomNavigationBarItem(
            icon: Text('⚔️', style: TextStyle(fontSize: 24)),
            label: '修練場',
          ),
          BottomNavigationBarItem(
            icon: Text('📜', style: TextStyle(fontSize: 24)),
            label: '寄合所',
          ),
          BottomNavigationBarItem(
            icon: Text('⛩️', style: TextStyle(fontSize: 24)),
            label: '寺院',
          ),
          BottomNavigationBarItem(
            icon: Text('🏮', style: TextStyle(fontSize: 24)),
            label: '門前町',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD4A038),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1A1040),
      ),
    );
  }
}
