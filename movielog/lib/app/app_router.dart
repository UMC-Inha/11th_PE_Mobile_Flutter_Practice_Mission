import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/home/presentation/home_screen.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/movies/presentation/movie_search_screen.dart';
import 'package:movielog/features/my_page/presentation/edit_profile_screen.dart';
import 'package:movielog/features/my_page/presentation/favorites_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/my_page/presentation/my_ratings_screen.dart';
import 'package:movielog/features/shell/presentation/main_shell.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/features/start/presentation/splash_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/member_session_gate.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

/// Route 경로를 한곳에 모아 오타로 인한 이동 실패를 막는다.
abstract final class AppRoutes {
  /// 앱을 켠 직후의 시작(스플래시) 화면. 토큰을 확인하는 동안 머문다.
  static const start = '/';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  /// 마이페이지의 자식 화면. 하단 NavigationBar를 가리도록 root Navigator 위에 열린다.
  static const myRatings = '/my/ratings';

  /// 프로필(닉네임) 수정. 마이페이지의 자식 화면이라 하단 NavigationBar를 가린다.
  static const editProfile = '/my/profile/edit';

  /// 내 즐겨찾기. 마이페이지의 자식 화면이라 하단 NavigationBar를 가린다.
  static const myFavorites = '/my/favorites';

  /// 영화 검색. 상세(`/movies/:movieId`)보다 **먼저** 등록해야 `search`가 영화 id로 해석되지 않는다.
  static const movieSearch = '/movies/search';

  /// TMDB 영화 id → `/movies/550`
  static String movieDetail(int movieId) => '$movies/$movieId';
}

/// 인증 상태와 현재 위치로 어디로 보낼지 정한다. 이동하지 않아도 되면 null.
///
/// 상태만 읽고 판단한다(비동기 작업·API 호출은 하지 않는다). 로그인·로그아웃·만료가 모두
/// 상태를 바꾸기만 하면 이 규칙 한곳에서 이동이 정해진다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {AppRoutes.login, AppRoutes.signUp};
  final atStart = location == AppRoutes.start;
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중 또는 확인 실패(재시도 버튼): 시작 화면을 유지한다.
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : AppRoutes.start,
    // 로그아웃 또는 로그인 요청 중: 공개 화면(로그인·회원가입)만 허용한다.
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : AppRoutes.login,
    // 로그인됨: 시작·로그인·회원가입 화면은 홈으로 보낸다.
    AuthStatus.signedIn => (atStart || atPublic) ? AppRoutes.home : null,
  };
}

/// 앱 전체 Router.
///
/// 공용 Service(TMDB·자체 API)는 MovieLogApp의 MultiProvider가 최상단에서 제공하고,
/// 화면마다 하나씩인 ViewModel은 각 Route 안에서 ChangeNotifierProvider로 만든다.
/// 그래서 화면을 벗어나면 ViewModel도 함께 dispose된다.
///
/// 인증 상태가 바뀌면 `refreshListenable`(상태 전용)로 redirect를 다시 실행한다. GoRouter는 앱이 살아 있는
/// 동안 한 번만 만들어야 하므로 [MovieLogApp]의 State가 initState에서 한 번 호출한다.
GoRouter createAppRouter(
  AuthViewModel authViewModel, {
  String initialLocation = AppRoutes.start,
}) {
  // 앱 전체를 감싸는 root Navigator의 키. GoRoute는 parentNavigatorKey를 주지 않으면
  // 가장 가까운 ShellRoute의 Navigator를 쓰므로, 하단 NavigationBar를 가려야 하는
  // 자식 화면(/my/ratings, /my/favorites)에는 이 키를 지정한다.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // 로그인 전에 요청한 위치(개발용 INITIAL_LOCATION, 테스트의 시작 위치)를 한 번만 기억했다가
  // 로그인에 성공하면 홈 대신 그곳으로 보낸다. 시작·공개 화면을 요청했다면 기억할 것이 없다.
  String? pendingLocation =
      initialLocation == AppRoutes.start ||
          initialLocation == AppRoutes.login ||
          initialLocation == AppRoutes.signUp
      ? null
      : initialLocation;

  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
    // 상태가 바뀔 때만 redirect를 다시 실행한다(내 정보·문구 변경에는 반응하지 않는다).
    refreshListenable: authViewModel.statusListenable,
    redirect: (context, state) {
      final target = authRedirect(authViewModel.status, state.uri.path);
      if (target == AppRoutes.home && pendingLocation != null) {
        final pending = pendingLocation;
        pendingLocation = null;
        return pending;
      }
      return target;
    },
    routes: [
      GoRoute(
        path: AppRoutes.start,
        name: 'start',
        // 토큰 확인 중에는 인디케이터, 확인 실패(retryRequired)에는 다시 시도 버튼.
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
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) {
          final extra = state.extra;
          return LoginScreen(initialEmail: extra is String ? extra : null);
        },
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
                builder: (context, state) => const MyPageScreen(),
                routes: [
                  GoRoute(
                    path: 'ratings', // 최종 경로: /my/ratings
                    name: 'myRatings',
                    parentNavigatorKey: rootNavigatorKey,
                    // 화면을 벗어나면 ViewModel도 dispose되어 늦게 온 응답이 버려진다.
                    builder: (context, state) => ChangeNotifierProvider(
                      create: (context) => MyRatingsViewModel(
                        context.read<RatingApiService>(),
                        context.read<TmdbMovieService>(),
                        context.read<AuthViewModel>(),
                        context.read<SessionRatings>(),
                      )..loadMovies(),
                      child: const MyRatingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'favorites', // 최종 경로: /my/favorites
                    name: 'myFavorites',
                    // 하단 NavigationBar를 가리도록 root Navigator 위에 연다.
                    parentNavigatorKey: rootNavigatorKey,
                    // 내 정보가 준비되고 현재 세션과 일치할 때까지 로딩·오류(다시 시도)를 보여 준다.
                    builder: (context, state) => MemberSessionGate(
                      title: '내 즐겨찾기',
                      builder: (context, member, guard) =>
                          ChangeNotifierProvider(
                            // 계정이나 세션이 바뀌면 이전 사용자의 ViewModel을 버리고 새로 만든다.
                            // 닉네임 수정처럼 값이 그대로면 key도 그대로라 상태가 유지된다.
                            key: ValueKey('${member.email}:${guard.generation}'),
                            create: (context) => FavoritesViewModel(
                              favoriteApi: context.read<FavoriteApiService>(),
                              tmdbApi: context.read<TmdbMovieService>(),
                              auth: context.read<AuthViewModel>(),
                              sessionGuard: guard,
                              accountId: member.email,
                            ),
                            child: const FavoritesScreen(),
                          ),
                    ),
                  ),
                  GoRoute(
                    path: 'profile/edit', // 최종 경로: /my/profile/edit
                    name: 'editProfile',
                    // 하단 NavigationBar를 가리도록 root Navigator 위에 연다.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final auth = context.watch<AuthViewModel>();
                      // 내 정보를 아직 못 받았으면 수정할 값이 없다. 마이페이지의 수정 버튼은
                      // member가 있을 때만 켜지지만, 직접 주소로 들어오는 경우를 대비한다.
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
                      return ChangeNotifierProvider(
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
        ],
      ),
      // 검색은 탭 바깥(전체 화면)에 둔다. 정적인 `search`를 동적인 `:movieId`보다 **먼저** 등록한다.
      // 순서가 바뀌면 /movies/search가 영화 id "search"로 해석된다.
      GoRoute(
        path: AppRoutes.movieSearch,
        name: 'movieSearch',
        // 영화 목록과는 별도의 PagedMoviesViewModel 인스턴스. 화면을 벗어나면 함께 dispose된다.
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              PagedMoviesViewModel(context.read<TmdbMovieService>()),
          child: const MovieSearchScreen(),
        ),
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
          // 목록에서 넘겨준 DTO가 같은 영화일 때만 쓴다.
          final listedMovie = extra is TmdbMovieDto && extra.id == movieId
              ? extra
              : null;
          return MemberSessionGate(
            title: '영화 상세',
            builder: (context, member, guard) => ChangeNotifierProvider(
              // 즐겨찾기 상태는 사용자별이다. 계정·세션이 바뀌면 이전 계정의 상태를 버린다.
              key: ValueKey('${member.email}:${guard.generation}'),
              create: (context) => FavoriteDetailViewModel(
                movieId: movieId,
                favoriteApi: context.read<FavoriteApiService>(),
                auth: context.read<AuthViewModel>(),
                sessionGuard: guard,
                accountId: member.email,
              ),
              child: ChangeNotifierProvider(
                create: (context) => MovieDetailViewModel(
                  context.read<TmdbMovieService>(),
                  context.read<RatingApiService>(),
                  context.read<AuthViewModel>(),
                  context.read<SessionRatings>(),
                  movieId: movieId,
                  movie: listedMovie,
                )..loadIfNeeded(),
                child: const MovieDetailScreen(),
              ),
            ),
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
