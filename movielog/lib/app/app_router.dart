import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/features/home/presentation/home_screen.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/shell/presentation/main_shell.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/features/start/presentation/start_screen.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:provider/provider.dart';

/// Route 경로를 한곳에 모아 오타로 인한 이동 실패를 막는다.
abstract final class AppRoutes {
  static const start = '/';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  /// TMDB 영화 id → `/movies/550`
  static String movieDetail(int movieId) => '$movies/$movieId';
}

/// 앱 전체 Router.
///
/// 공용 Service(TMDB·자체 API)는 MovieLogApp의 MultiProvider가 최상단에서 제공하고,
/// 화면마다 하나씩인 ViewModel은 각 Route 안에서 ChangeNotifierProvider로 만든다.
/// 그래서 화면을 벗어나면 ViewModel도 함께 dispose된다.
GoRouter createAppRouter({String initialLocation = AppRoutes.start}) {
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
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              SignUpViewModel(context.read<MovieLogApiService>()),
          child: const SignUpScreen(),
        ),
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
                builder: (context, state) => ChangeNotifierProvider(
                  // create는 이 화면이 처음 만들어질 때 한 번만 실행된다.
                  create: (context) =>
                      MovieHomeViewModel(context.read<TmdbMovieService>())
                        ..loadPopular(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.movies,
                name: 'movies',
                // Query Parameter: /movies?genres=28,12 (TMDB 장르 ID)
                // 없으면 마지막에 저장한 장르를 복원한다.
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => MovieListViewModel(
                    context.read<TmdbMovieService>(),
                    preferences: context.read<MoviePreferences>(),
                    initialGenreIds:
                        state.uri.queryParameters.containsKey('genres')
                        ? parseGenreIds(state.uri.queryParameters['genres'])
                        : null,
                  )..loadInitial(),
                  child: const MovieListScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.my,
                name: 'my',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => MyRatingsViewModel(
                    context.read<MovieLogApiService>(),
                    context.read<TmdbMovieService>(),
                  )..load(),
                  child: const MyPageScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // 상세는 탭 바깥(전체 화면)에 둔다. Path의 movieId는 TMDB id다.
      GoRoute(
        path: '${AppRoutes.movies}/:movieId',
        name: 'movieDetail',
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');
          if (movieId == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('영화를 찾을 수 없어요.')),
            );
          }
          final extra = state.extra;
          return ChangeNotifierProvider(
            create: (context) => MovieDetailViewModel(
              context.read<TmdbMovieService>(),
              movieId: movieId,
              // 목록에서 넘겨준 DTO가 같은 영화일 때만 쓴다.
              movie: extra is TmdbMovieDto && extra.id == movieId
                  ? extra
                  : null,
            )..loadIfNeeded(),
            child: const MovieDetailScreen(),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('페이지를 찾을 수 없어요')),
      body: Center(child: Text('${state.uri} 경로가 없습니다.')),
    ),
  );
}

/// [28, 12] → `/movies?genres=28,12`, 비어 있으면 `/movies`
String moviesLocation(List<int> genreIds) {
  if (genreIds.isEmpty) return AppRoutes.movies;
  return Uri(
    path: AppRoutes.movies,
    queryParameters: {'genres': genreIds.join(',')},
  ).toString();
}
