import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/detail/movie_detail_loader.dart';
import '../screens/home/home_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/movies/movie_list_screen.dart';
import '../screens/my_ratings/my_ratings_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/signup/sign_up_screen.dart';
import '../start_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_rating_store.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 또는 확인 실패(재시도 버튼): 스플래시 화면 유지
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    // 로그아웃 또는 로그인 요청 중: 공개 화면만 허용
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    // 로그인됨: 스플래시와 로그인·회원가입 화면은 홈으로 보냄
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

/// [AuthViewModel]의 알림 중 [AuthViewModel.status]가 바뀐 경우만 Router에 전달합니다.
///
/// 프로필 수정 성공 시 updateMember()의 알림까지 Router가 받으면 redirect가 다시 실행되면서
/// 직후의 pop()이 취소되어 마이페이지로 돌아가지 못합니다.
class AuthStatusListenable extends ChangeNotifier {
  AuthStatusListenable(this._auth) : _last = _auth.status {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  AuthStatus _last;

  void _onAuthChanged() {
    if (_auth.status == _last) return;
    _last = _auth.status;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

class AppRouter {
  AppRouter._();

  /// 앱 전체의 root Navigator를 가리키는 키입니다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // 인증 상태가 바뀌면 redirect를 다시 실행합니다.
      refreshListenable: AuthStatusListenable(authViewModel),
      redirect: (context, state) {
        return authRedirect(authViewModel.status, state.uri.path);
      },
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login', // 새로 추가하는 로그인 Route
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
            child: const SignUpScreen(),
          ),
        ),
        // 3주차에서 만든 ShellRoute 구조를 그대로 사용합니다.
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
                  // 7주차까지 쓰던 memberId 대신 토큰 기반 Service를 사용합니다.
                  builder: (context, state) =>
                      ChangeNotifierProvider<MyRatingsViewModel>(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          context.read<AuthViewModel>(),
                          context.read<SessionRatingStore>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                ),
                // 마이페이지 수정 버튼은 member != null일 때만 켭니다.
                GoRoute(
                  path: 'profile/edit',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    if (auth.member == null) {
                      return Scaffold(
                        appBar: AppBar(
                          centerTitle: true,
                          title: const Text('프로필 수정'),
                        ),
                        body: Center(
                          child: auth.memberStatus == MemberLoadStatus.error
                              ? MovieLogButton(
                                  label: '다시 시도',
                                  onPressed: () =>
                                      auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        auth,
                      ),
                      child: const EditProfileScreen(),
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
  }

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;

    return 0;
  }
}
