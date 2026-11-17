import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../view_models/auth_view_model.dart';

/// 홈·영화·마이 탭이 공통으로 사용하는 NavigationBar 레이아웃입니다.
/// body에는 ShellRoute가 전달한 child(탭 화면)만 바뀌어 표시됩니다.
// 3주차의 StatelessWidget을 StatefulWidget으로 바꿔 initState에서 한 번 호출합니다.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 어느 탭으로 진입하든 내 정보를 한 번 불러와 AuthViewModel.member에 보관합니다.
      context.read<AuthViewModel>().loadMember();
    });
  }

  static const _tabLocations = ['/home', '/movies', '/my'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: (index) {
          if (index == widget.currentIndex) return;
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
