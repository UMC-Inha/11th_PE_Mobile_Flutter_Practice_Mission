import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:provider/provider.dart';

/// 홈 · 영화 · 마이페이지를 오가는 하단 NavigationBar.
///
/// StatefulShellRoute.indexedStack이 넘겨주는 navigationShell의
/// currentIndex를 그대로 쓰므로 선택된 탭과 화면이 항상 일치한다.
///
/// 로그인한 사용자만 이 화면 안으로 들어온다(Router의 redirect). 처음 열릴 때 **한 번**
/// 내 정보를 불러와 [AuthViewModel.member]에 보관한다. 어느 탭으로 진입하든(홈을 거치지 않고
/// 바로 마이페이지로 와도) 같은 값을 쓰게 하려는 것이다. 탭을 바꿔도 이 위젯은 유지되어
/// initState는 한 번만 실행되고, 로그아웃 뒤 다시 로그인하면 새로 만들어져 다시 부른다.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    // loadMember는 첫 줄에서 notifyListeners를 부르므로 build·initState 도중이 아니라
    // 첫 프레임이 끝난 뒤에 호출한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().loadMember();
    });
  }

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
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
            label: '마이페이지',
          ),
        ],
      ),
    );
  }
}
