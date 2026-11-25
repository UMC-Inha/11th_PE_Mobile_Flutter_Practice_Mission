import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/install_guard.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/session_rating_store.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.signUpService,
    this.ratingApiService,
    this.tmdbMovieService,
  });

  /// 테스트에서 실제 서버 대신 가짜 Service를 넣을 때 사용합니다.
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final TmdbMovieService? tmdbMovieService;

  @override
  Widget build(BuildContext context) {
    final tokenStorage = SecureTokenStorage(const FlutterSecureStorage());
    final publicClient = createMovieLogClient(); // Interceptor 없음
    final authClient = createAuthMovieLogClient(tokenStorage); // Interceptor 등록

    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: tokenStorage),
        Provider<TmdbMovieService>(
          create: (_) =>
              tmdbMovieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client
        Provider<AuthApiService>(
          create: (_) => AuthApiService(publicClient),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(publicClient),
        ),
        // 보호 Client (RatingApiService는 공개 조회용 publicClient도 함께 받음)
        Provider<MemberApiService>(
          create: (_) => MemberApiService(authClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              ratingApiService ?? RatingApiService(publicClient, authClient),
        ),
        // Service를 주입받는 ViewModel
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 현재 세션에서 등록 response로 받은 Rating을 보관합니다.
        ChangeNotifierProvider<SessionRatingStore>(
          create: (context) => SessionRatingStore(context.read<AuthViewModel>()),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 최초 설치 flag 확인 → (없으면) secure storage 정리 → 그 다음 세션 복원
      try {
        await clearSecureStorageOnFirstLaunch();
      } catch (_) {
        // 정리에 실패하면 flag를 남기지 않아 다음 실행에서 다시 시도합니다.
        // 남은 토큰도 restoreSession()의 GET me 검증을 거치므로 바로 signedIn이 되지 않습니다.
      }
      if (mounted) authViewModel.restoreSession();
    }); // 첫 build 이후 세션 복원을 시작합니다.
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      routerConfig: _router,
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
