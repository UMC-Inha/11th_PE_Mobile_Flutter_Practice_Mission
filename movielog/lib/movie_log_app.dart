import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      // Chrome, 데스크톱처럼 넓은 창에서도 모바일 화면 폭으로 보이도록 제한합니다.
      // 회원가입 넓은 화면 Challenge를 확인할 때는 이 값을 늘려서 확인합니다.
      builder: (context, child) => ColoredBox(
        color: AppColors.warmWhite,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: child,
          ),
        ),
      ),
      routerConfig: AppRouter.router,
    );
  }
}
