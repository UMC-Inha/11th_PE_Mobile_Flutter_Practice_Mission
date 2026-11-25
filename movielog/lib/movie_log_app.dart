import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'view_models/learning_member_session.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.signUpService,
    this.ratingApiService,
    this.tmdbMovieService,
    this.learningMemberSession,
  });

  /// 테스트에서 실제 서버 대신 가짜 Service를 넣을 때 사용합니다.
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final TmdbMovieService? tmdbMovieService;

  /// 테스트에서 이미 가입한 학습용 회원으로 시작할 때 사용합니다.
  final LearningMemberSession? learningMemberSession;

  @override
  Widget build(BuildContext context) {
    // 워크북 백엔드를 부르는 두 Service는 Dio 하나를 공유합니다.
    // TMDB Client와는 baseUrl·헤더가 다르므로 합치지 않습니다.
    final movieLogClient = createMovieLogClient();

    // 여러 Route가 함께 쓰는 Service는 MaterialApp.router 바깥에서 한 번만 등록합니다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) =>
              tmdbMovieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 회원가입 결과의 memberId를 영화 상세·마이페이지 Route가 함께 읽습니다.
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => learningMemberSession ?? LearningMemberSession(),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) => ratingApiService ?? RatingApiService(movieLogClient),
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
