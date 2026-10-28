import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/screens/detail/movie_detail_screen.dart';
import 'package:movielog/screens/home/widgets/featured_movie_banner.dart';

import 'package:movielog/screens/home/home_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/widgets/tmdb_movie_card.dart';

import 'fakes/fake_tmdb_movie_service.dart';

Widget _homeWith(FakeTmdbMovieService service) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MovieHomeViewModel>(
      create: (_) => MovieHomeViewModel(service)..loadPopular(),
      child: const HomeScreen(),
    ),
  );
}

void main() {
  setUp(() {
    // 추천 배너 아래의 인기 영화 영역까지 한 화면에 그려지도록 모바일 폭·긴 높이로 맞춥니다.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(430, 1400);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  testWidgets('Popular 결과 중 앞 5개만 홈에 표시하고, 다시 그려도 재요청하지 않는다', (tester) async {
    final service = FakeTmdbMovieService(popularIds: [1, 2, 3, 4, 5, 6, 7]);
    await tester.pumpWidget(_homeWith(service));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TmdbMovieCard, '영화 1'), findsOneWidget);

    // 가로 목록은 보이는 카드만 그리므로 끝까지 스크롤해 5번째까지만 있는지 확인합니다.
    await tester.drag(find.byType(TmdbMovieCard).first, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TmdbMovieCard, '영화 5'), findsOneWidget);
    expect(find.widgetWithText(TmdbMovieCard, '영화 6'), findsNothing);

    await tester.pumpWidget(_homeWith(service));
    await tester.pumpAndSettle();
    expect(service.popularRequestCount, 1);
  });

  testWidgets('결과가 5개보다 적어도 범위 오류 없이 있는 만큼 표시한다', (tester) async {
    final service = FakeTmdbMovieService(popularIds: [1, 2]);
    await tester.pumpWidget(_homeWith(service));
    await tester.pumpAndSettle();

    expect(find.byType(TmdbMovieCard), findsNWidgets(2));
  });

  testWidgets('포스터가 없거나 이미지 로드에 실패하면 placeholder를 표시한다', (tester) async {
    // 테스트 환경의 네트워크 이미지는 모두 로드에 실패하므로, 1번은 null, 2번은 로드 실패 경우입니다.
    // 1번은 추천 배너와 카드에 모두 표시되므로 placeholder는 3개입니다.
    final service = FakeTmdbMovieService(popularIds: [1, 2], idsWithoutPoster: {1});
    await tester.pumpWidget(_homeWith(service));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(3));
  });

  testWidgets('추천 배너를 누르면 TMDB id로 상세에 이동하고 같은 영화를 보여준다', (tester) async {
    final service = FakeTmdbMovieService(popularIds: [969681, 2, 3]);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => ChangeNotifierProvider<MovieHomeViewModel>(
            create: (_) => MovieHomeViewModel(service)..loadPopular(),
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) => MovieDetailScreen(movie: state.extra as TmdbMovieDto?),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('상세보기'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/movies/969681');
    expect(find.byType(MovieDetailScreen), findsOneWidget);
    expect(find.text('영화 969681'), findsOneWidget);
  });

  testWidgets('인기 영화를 불러오기 전에는 추천 배너를 숨긴다', (tester) async {
    final service = FakeTmdbMovieService(popularIds: const []);
    await tester.pumpWidget(_homeWith(service));
    await tester.pumpAndSettle();

    expect(find.byType(FeaturedMovieBanner), findsNothing);
    expect(find.text('인기 영화가 없어요.'), findsOneWidget);
  });
}
