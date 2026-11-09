import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/detail/movie_detail_loader.dart';
import '../screens/home/home_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/movies/movie_list_screen.dart';
import '../screens/my_ratings/my_ratings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/signup/sign_up_screen.dart';
import '../start_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/sign_up_view_model.dart';

class AppRouter {
  AppRouter._();

  /// 앱 전체의 root Navigator를 가리키는 키입니다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: '/start',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
          create: (context) => SignUpViewModel(context.read<SignUpService>()),
          child: const SignUpScreen(),
        ),
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
            builder: (context, state) =>
                ChangeNotifierProvider<MovieHomeViewModel>(
                  create: (context) =>
                      MovieHomeViewModel(context.read<TmdbMovieService>())
                        ..loadPopular(),
                  child: const HomeScreen(),
                ),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) =>
                ChangeNotifierProvider<MovieListViewModel>(
                  create: (context) =>
                      MovieListViewModel(context.read<TmdbMovieService>())
                        ..loadInitial(),
                  child: const MovieListScreen(),
                ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'ratings', // 최종 경로: /my/ratings
                // root Navigator 위에 표시해 하단 NavigationBar를 가립니다.
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  // 6주차 고정 ID 대신 회원가입 결과로 보관한 학습용 memberId를 사용합니다.
                  final id = context.read<LearningMemberSession>().memberId;
                  if (id == null) return const _SignUpRequiredScreen();
                  return ChangeNotifierProvider<MyRatingsViewModel>(
                    create: (context) => MyRatingsViewModel(
                      context.read<RatingApiService>(),
                      context.read<TmdbMovieService>(),
                      id,
                    )..load(),
                    child: const MyRatingsScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          // movieId는 URL 식별자이고, 화면에 쓸 TMDB 영화는 extra에서 꺼냅니다.
          final id = int.tryParse(state.pathParameters['movieId'] ?? '');
          if (id == null || id < 1) {
            return const Scaffold(
              body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
            );
          }
          // 목록·홈 카드가 extra로 넘긴 영화가 없으면 Loader가 TMDB에서 다시 조회합니다.
          final extra = state.extra;
          return MovieDetailLoader(
            movieId: id,
            initialMovie: extra is TmdbMovieDto && extra.id == id
                ? extra
                : null,
          );
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

/// 학습용 회원가입 전에 "내가 등록한 평점"에 들어왔을 때의 안내 화면입니다.
class _SignUpRequiredScreen extends StatelessWidget {
  const _SignUpRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: AppColors.violet),
        centerTitle: true,
        title: Text(
          '내가 등록한 평점',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
        ),
      ),
      body: const Center(
        child: Text('학습용 회원가입이 필요합니다.', style: AppTextStyles.bodyMedium),
      ),
    );
  }
}
