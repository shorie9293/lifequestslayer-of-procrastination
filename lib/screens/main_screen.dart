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
  final PageController _pageController = PageController(initialPage: 0); // スワイプ用のページコントローラー

  final List<Widget> _screens = [
    const HomeScreen(),
    const GuildScreen(),
    const TempleScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // リソースを解放
    _pageController.dispose();
    super.dispose();
  }

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
      // 画面をスワイプできるようにPageViewを利用する
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      // BottomNavigationBarを追加（Add BottomNavigationBar for smartphones）
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // タブがタップされたときにスワイプアニメーションでページを切り替える
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '戦場',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'ギルド',
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
