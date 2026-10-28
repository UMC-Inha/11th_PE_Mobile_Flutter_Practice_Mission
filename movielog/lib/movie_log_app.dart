import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/member_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, this.memberService});

  /// 테스트에서 실제 서버 대신 가짜 Service를 넣을 때 사용합니다.
  final MemberService? memberService;

  @override
  Widget build(BuildContext context) {
    // 여러 Route가 함께 쓰는 Service는 MaterialApp.router 바깥에서 한 번만 등록합니다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        Provider<MemberService>(
          create: (_) => memberService ?? MemberService(createApiClient()),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        scrollBehavior: const _MovieLogScrollBehavior(),
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
      ),
    );
  }
}

/// Flutter는 웹·데스크톱에서 마우스 드래그 스크롤을 기본으로 막습니다.
/// Chrome에서도 홈 인기 영화·장르 Chip 같은 가로 목록을 마우스로 끌어 스크롤할 수 있게 허용합니다.
class _MovieLogScrollBehavior extends MaterialScrollBehavior {
  const _MovieLogScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
