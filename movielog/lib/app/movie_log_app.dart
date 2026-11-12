import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:provider/provider.dart';

class MovieLogApp extends StatefulWidget {
  const MovieLogApp({
    super.key,
    this.initialLocation = AppRoutes.start,
    this.tmdbService,
    this.movieLogApiService,
    this.preferences,
    this.session,
  });

  /// 테스트나 개발 중 원하는 화면부터 띄울 때 사용한다.
  final String initialLocation;

  /// null이면 실제 TMDB·자체 백엔드 Client로 만든다. 테스트는 가짜를 넣는다.
  final TmdbMovieService? tmdbService;
  final MovieLogApiService? movieLogApiService;
  final MoviePreferences? preferences;

  /// 테스트에서 가입을 마친 상태로 시작하려고 넣는다. null이면 비어 있는 새 세션을 만든다.
  final LearningMemberSession? session;

  @override
  State<MovieLogApp> createState() => _MovieLogAppState();
}

class _MovieLogAppState extends State<MovieLogApp> {
  // build마다 Router를 새로 만들면 화면 상태가 초기화되므로 한 번만 만든다.
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 여러 Route가 함께 쓰는 객체는 MaterialApp.router 바깥 최상단에 둔다.
    // Provider가 특정 화면 아래에만 있으면 다른 Route에서 context.read로 찾지 못한다.
    return MultiProvider(
      providers: [
        Provider<TmdbMovieService>(
          create: (_) =>
              widget.tmdbService ?? TmdbMovieService(createTmdbClient()),
        ),
        Provider<MovieLogApiService>(
          create: (_) =>
              widget.movieLogApiService ??
              MovieLogApiService(createMovieLogApiClient()),
        ),
        Provider<MoviePreferences>(
          create: (_) => widget.preferences ?? GenrePreference(),
        ),
        // 회원가입 결과의 memberId를 여러 Route(영화 상세·마이페이지)가 같이 읽는다.
        // 메모리에만 있어 앱을 다시 시작하면 사라지며, 로그인(인증)이 아니다.
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => widget.session ?? LearningMemberSession(),
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
