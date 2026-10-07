import 'package:flutter/material.dart';
import 'package:movielog/core/services/fake_movie_service.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/features/home/presentation/home_screen.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/shell/presentation/main_shell.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/features/start/presentation/start_screen.dart';

/// Route 경로를 한곳에 모아 오타로 인한 이동 실패를 막는다.
abstract final class AppRoutes {
  static const start = '/';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  static String movieDetail(String movieId) => '$movies/$movieId';
}

/// 앱 전체 Router.
///
/// 시작 → 회원가입, 회원가입 → 홈은 go로 이동해 스택을 교체한다.
/// 그래서 회원가입·홈 화면에서는 뒤로 가기가 동작하지 않는다.
/// 홈 · 영화 · 마이페이지는 StatefulShellRoute.indexedStack으로 묶어
/// 탭마다 Navigation 상태(스크롤, 상세 화면 스택)를 보존한다.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.start,
  MovieService movieService = const FakeMovieService(),
  MoviePreferences? preferences,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.start,
        name: 'start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        builder: (context, state) => const SignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.movies,
                name: 'movies',
                // Query Parameter: /movies?genres=SF,드라마
                builder: (context, state) => MovieListScreen(
                  service: movieService,
                  preferences: preferences,
                  restoreSavedGenre: !state.uri.queryParameters.containsKey(
                    'genres',
                  ),
                  initialMode: MovieLoadMode.values.firstWhere(
                    (mode) => mode.name == state.uri.queryParameters['mode'],
                    orElse: () => MovieLoadMode.success,
                  ),
                  selectedGenres: parseGenres(
                    state.uri.queryParameters['genres'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.my,
                name: 'my',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),
      // 상세는 탭 바깥(전체 화면)에 둔다. 홈·목록 어디서 push해도
      // 뒤로 가면 누른 곳으로 정확히 돌아온다.
      GoRoute(
        path: '${AppRoutes.movies}/:movieId',
        name: 'movieDetail',
        // Path Parameter: /movies/under-the-starlight
        builder: (context, state) =>
            MovieDetailScreen(movieId: state.pathParameters['movieId']),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('페이지를 찾을 수 없어요')),
      body: Center(child: Text('${state.uri} 경로가 없습니다.')),
    ),
  );
}

/// `?genres=SF,드라마` → {'SF', '드라마'}
Set<String> parseGenres(String? raw) {
  if (raw == null || raw.trim().isEmpty) return {};
  return raw.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toSet();
}

/// {'SF', '드라마'} → `/movies?genres=SF,드라마`, 비어 있으면 `/movies`
String moviesLocation(Set<String> genres) {
  if (genres.isEmpty) return AppRoutes.movies;
  return Uri(
    path: AppRoutes.movies,
    queryParameters: {'genres': genres.join(',')},
  ).toString();
}
