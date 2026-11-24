import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/storage/email_preference.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:provider/provider.dart';

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({
    super.key,
    this.initialLocation = AppRoutes.start,
    this.tmdbService,
    this.movieLogApiService,
    this.authApiService,
    this.memberApiService,
    this.ratingApiService,
    this.favoriteApiService,
    this.movieRecordApiService,
    this.tokenStorage,
    this.emailPreference,
    this.preferences,
  });

  /// 테스트나 개발 중 원하는 화면부터 띄울 때 사용한다. 로그인 전에는 Router가 시작·로그인
  /// 화면으로 되돌리므로, 보호 화면은 로그인(또는 세션 복원) 뒤에만 열린다.
  final String initialLocation;

  /// null이면 실제 TMDB·자체 백엔드 Client로 만든다. 테스트는 가짜를 넣는다.
  final TmdbMovieService? tmdbService;
  final MovieLogApiService? movieLogApiService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final RatingApiService? ratingApiService;
  final FavoriteApiService? favoriteApiService;
  final MovieRecordApiService? movieRecordApiService;

  /// null이면 보안 저장소(SecureTokenStorage). 테스트는 메모리 저장소를 넣는다.
  final TokenStorage? tokenStorage;
  final EmailPreference? emailPreference;
  final MoviePreferences? preferences;

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // 토큰 저장소와 Dio Client, Service, ViewModel, Router는 앱이 살아 있는 동안 한 번만 만든다.
  // build()에서 만들면 화면이 다시 그려질 때마다 새로 생겨 현재 위치와 인증 상태가 초기화된다.
  late final TokenStorage _tokenStorage =
      widget.tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());

  // 공개 Client: 로그인·회원가입·중복 확인·유저별 평점 조회. 토큰을 붙이지 않는다.
  late final Dio _publicClient = createMovieLogApiClient();

  // 보호 Client: 내 정보·평점·즐겨찾기. AuthInterceptor가 보호 경로에만 Bearer를 붙인다.
  late final Dio _authClient = createAuthMovieLogApiClient(_tokenStorage);

  late final AuthApiService _authApi =
      widget.authApiService ?? AuthApiService(_publicClient);
  late final MemberApiService _memberApi =
      widget.memberApiService ?? MemberApiService(_authClient);
  late final AuthViewModel _auth = AuthViewModel(
    _authApi,
    _memberApi,
    _tokenStorage,
  );
  late final GoRouter _router = createAppRouter(
    _auth,
    initialLocation: widget.initialLocation,
  );

  @override
  void initState() {
    super.initState();
    // 첫 build 이후에 세션 복원을 시작한다(복원 중에는 시작 화면이 보인다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _auth.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 여러 Route가 함께 쓰는 객체는 MaterialApp.router 바깥 최상단에 둔다.
    // Provider가 특정 화면 아래에만 있으면 다른 Route에서 context.read로 찾지 못한다.
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        // TMDB Client에는 MovieLog JWT를 절대 붙이지 않는다. 두 Client는 합치지 않는다.
        Provider<TmdbMovieService>(
          create: (_) =>
              widget.tmdbService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<MovieLogApiService>(
          create: (_) =>
              widget.movieLogApiService ?? MovieLogApiService(_publicClient),
        ),
        Provider<MemberApiService>.value(value: _memberApi),
        Provider<RatingApiService>(
          create: (_) =>
              widget.ratingApiService ?? RatingApiService(_authClient),
        ),
        Provider<FavoriteApiService>(
          create: (_) =>
              widget.favoriteApiService ?? FavoriteApiService(_authClient),
        ),
        Provider<MovieRecordApiService>(
          create: (_) =>
              widget.movieRecordApiService ?? MovieRecordApiService(_authClient),
        ),
        Provider<EmailPreference>(
          create: (_) => widget.emailPreference ?? SharedEmailPreference(),
        ),
        Provider<MoviePreferences>(
          create: (_) => widget.preferences ?? GenrePreference(),
        ),
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
        // 이번 로그인 세션에서 등록한 평점. 세션이 바뀌면 비운다.
        ChangeNotifierProvider<SessionRatings>(
          create: (_) => SessionRatings(_auth),
        ),
        // 인증 상태(sessionVersion·검증된 email)가 바뀔 때마다 세션 판정기를 새로 시작한다.
        // 앱을 켠 때부터 AuthViewModel을 지켜봐야 하므로 lazy하지 않게 만든다.
        Provider<AuthSessionBridge>(
          lazy: false,
          create: (context) {
            final auth = context.read<AuthViewModel>();
            return AuthSessionBridge(
              authSignals: auth,
              sessionVersion: () => auth.sessionVersion,
              verifiedEmail: () =>
                  auth.status == AuthStatus.signedIn ? auth.member?.email : null,
            );
          },
          dispose: (_, bridge) => bridge.dispose(),
        ),
        Provider<SessionGuard>(
          create: (context) => context.read<AuthSessionBridge>().guard,
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
