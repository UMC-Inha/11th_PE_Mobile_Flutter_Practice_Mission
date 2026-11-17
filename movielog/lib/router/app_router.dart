import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/api_config.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/detail/movie_detail_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/movies/movie_list_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/signup/sign_up_screen.dart';
import '../start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          );
        },
        routes: [
          // 화면별 ViewModel은 각 Route에서 생성하고, 생성 직후 첫 요청을 한 번만 보냅니다.
          GoRoute(
            path: '/home',
            builder: (context, state) => ChangeNotifierProvider<MovieHomeViewModel>(
              create: (context) => MovieHomeViewModel(
                context.read<TmdbMovieService>(),
              )..loadPopular(),
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) => ChangeNotifierProvider<MovieListViewModel>(
              create: (context) => MovieListViewModel(
                context.read<TmdbMovieService>(),
              )..loadInitial(),
              child: const MovieListScreen(),
            ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => ChangeNotifierProvider<MyRatingsViewModel>(
              create: (context) => MyRatingsViewModel(
                context.read<MemberService>(),
                memberId: ApiConfig.myMemberId,
              )..load(),
              child: const ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');

          // 목록·홈 카드가 extra로 넘긴 TMDB 영화를 사용합니다.
          // TODO(TMDB 상세 API): extra 없이 URL로 직접 진입하면 /movie/{id}로 조회합니다.
          final extra = state.extra;
          final movie = extra is TmdbMovieDto && extra.id == movieId ? extra : null;

          return MovieDetailScreen(movie: movie);
        },
      ),
    ],
  );

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;

    return 0;
  }
}
