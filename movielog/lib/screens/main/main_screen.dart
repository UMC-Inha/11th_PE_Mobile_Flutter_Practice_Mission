import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 홈·영화·마이 탭이 공통으로 사용하는 NavigationBar 레이아웃입니다.
/// body에는 ShellRoute가 전달한 child(탭 화면)만 바뀌어 표시됩니다.
class MainScreen extends StatelessWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  static const _tabLocations = ['/home', '/movies', '/my'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == currentIndex) return;
          context.go(_tabLocations[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: '영화',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
