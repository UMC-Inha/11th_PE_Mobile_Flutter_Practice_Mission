import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/my_page/presentation/my_ratings_screen.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

import 'support.dart';

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  late AppHarness h;

  setUp(() {
    h = AppHarness();
    h.tmdb.moviesById
      ..[550] = movie(550, title: '파이트 클럽')
      ..[155] = movie(155, title: '다크 나이트');
    h.tmdb.perPage = 20;
  });

  /// 저장된 토큰으로 세션을 복원한 뒤 [location]까지 열린 상태로 만든다.
  Future<void> open(WidgetTester tester, String location) async {
    await tester.pumpWidget(h.app(initialLocation: location));
    await settle(tester);
  }

  final twoRatings = [
    memberRating(2, 155, score: 4, comment: '다시 봐도 명작'),
    memberRating(1, 550, score: 5, comment: '최고의 영화!'),
  ];

  testWidgets('마이페이지의 진입 행을 누르면 하단 NavigationBar 없는 자식 화면이 열린다', (
    tester,
  ) async {
    await open(tester, AppRoutes.my);
    seedRatings(tester, h, twoRatings);
    await settle(tester);

    // 마이페이지에는 하단 NavigationBar가 있고 평점 목록 자체는 없다.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(myRatingsEntryKey), findsOneWidget);
    expect(find.text('파이트 클럽'), findsNothing);

    await tester.tap(find.byKey(myRatingsEntryKey));
    await settle(tester);

    // root Navigator 위에 열리므로 NavigationBar가 가려진다.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('내가 등록한 평점'), findsOneWidget); // AppBar 제목
    expect(find.text('파이트 클럽'), findsOneWidget);

    // 뒤로 가면 마이페이지와 NavigationBar가 돌아온다.
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byKey(myRatingsEntryKey), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('주소로 /my/ratings를 바로 열어도 세션 복원 뒤 같은 화면이 열린다', (tester) async {
    await open(tester, AppRoutes.myRatings);
    expect(currentLocation(tester), AppRoutes.myRatings);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('내가 등록한 평점'), findsOneWidget);
    // 토큰으로 세션을 복원했으므로 로그인 화면으로 가지 않는다.
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('로그인하지 않은 채 /my/ratings 주소로 열면 로그인 화면으로 간다', (tester) async {
    h.storage.token = null;
    await open(tester, AppRoutes.myRatings);
    expect(currentLocation(tester), AppRoutes.login);
    expect(find.byKey(myRatingsSessionNoticeKey), findsNothing);
  });

  testWidgets('평점이 없으면 빈 상태이고 범위(이번 로그인만)를 알리며 편집은 숨긴다', (tester) async {
    await open(tester, AppRoutes.myRatings);

    expect(find.byKey(myRatingsEmptyKey), findsOneWidget);
    expect(find.text('이번 로그인에서 등록한 평점이 없어요.'), findsOneWidget);
    // 서버에 내 평점 조회 API가 없다는 사실을 숨기지 않는다.
    expect(find.byKey(myRatingsSessionNoticeKey), findsOneWidget);
    expect(find.textContaining('이번 로그인에서 등록한 평점만 보여요'), findsOneWidget);
    expect(find.byKey(myRatingsEditToggleKey), findsNothing);
    expect(find.text('-'), findsOneWidget); // 평균 없음
  });

  testWidgets('점수·후기·등록일·TMDB 제목과 평균이 함께 보인다', (tester) async {
    await open(tester, AppRoutes.myRatings);
    seedRatings(tester, h, twoRatings);
    await settle(tester);

    expect(find.byKey(myRatingsEmptyKey), findsNothing);
    expect(find.text('다크 나이트'), findsOneWidget);
    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(find.text('다시 봐도 명작'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(find.text('★★★★★  5점'), findsOneWidget);
    expect(find.textContaining('movieId 155'), findsOneWidget);
    expect(find.textContaining('2026.10.28'), findsNWidgets(2));
    expect(find.text('4.5'), findsOneWidget); // 평균
    expect(find.byKey(myRatingsNoticeKey), findsNothing);
    expect(find.byKey(myRatingsEditToggleKey), findsOneWidget);
  });

  testWidgets('후기가 없는 평점(comment: null)은 후기 줄을 그리지 않는다', (tester) async {
    await open(tester, AppRoutes.myRatings);
    seedRatings(tester, h, [memberRating(1, 550, score: 3, comment: null)]);
    await settle(tester);

    final tile = find.byKey(const Key('ratingTile-1'));
    expect(tile, findsOneWidget);
    // 제목 · 별점 · movieId/등록일 세 줄만 있다. 테스트 환경에서는 포스터 이미지가
    // 항상 로드에 실패해 "포스터 없음" 문구가 생기므로 그것만 빼고 센다.
    final lines = tester
        .widgetList<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .where((data) => data != '포스터 없음')
        .toList();
    expect(lines, ['파이트 클럽', '★★★☆☆  3점', 'movieId 550 · 2026.10.28']);
    expect(find.text('null'), findsNothing);
  });

  testWidgets('TMDB에서 영화를 못 찾아도 평점은 남고 제목·포스터만 placeholder', (tester) async {
    h.tmdb.notFoundMovieIds.add(155);
    await open(tester, AppRoutes.myRatings);
    seedRatings(tester, h, twoRatings);
    await settle(tester);

    expect(find.text('파이트 클럽'), findsOneWidget);
    // ratingId 2 = movieId 155. 이 타일만 제목·포스터가 placeholder다.
    final missing = find.byKey(const Key('ratingTile-2'));
    expect(
      find.descendant(of: missing, matching: find.text('영화 #155')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: missing, matching: find.byKey(posterPlaceholderKey)),
      findsOneWidget,
    );
    // 평점 자체와 movieId는 그대로 보인다.
    expect(find.text('다시 봐도 명작'), findsOneWidget);
    expect(find.textContaining('movieId 155'), findsOneWidget);
    expect(find.byKey(myRatingsNoticeKey), findsOneWidget);
    expect(find.textContaining('일부 영화 정보를 가져오지 못해'), findsOneWidget);
  });

  testWidgets('평점 항목을 누르면 TMDB id로 영화 상세가 열리고 뒤로 가면 목록으로 돌아온다', (tester) async {
    await open(tester, AppRoutes.myRatings);
    seedRatings(tester, h, twoRatings);
    await settle(tester);
    h.tmdb.movieCalls.clear();

    await tester.tap(find.byKey(const Key('ratingTile-1')));
    await settle(tester);
    expect(find.text('TMDB 영화 ID 550'), findsOneWidget);
    expect(h.tmdb.movieCalls, isEmpty); // 넘겨받은 영화는 다시 조회하지 않는다

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('내가 등록한 평점'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
  });

  testWidgets('로그아웃하면 목록이 비고, 다시 로그인한 새 세션에는 지난 평점이 보이지 않는다', (tester) async {
    await open(tester, AppRoutes.my);
    seedRatings(tester, h, twoRatings);
    await settle(tester);
    expect(sessionOf(tester).ratings, hasLength(2));

    await tester.tap(find.byKey(logoutButtonKey));
    await settle(tester);
    expect(currentLocation(tester), AppRoutes.login);
    expect(sessionOf(tester).ratings, isEmpty);

    // 같은 계정으로 다시 로그인해도 서버에서 내 평점을 읽어 오는 API가 없으니 비어 있다.
    await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
    await tester.enterText(find.byKey(loginPasswordFieldKey), 'Password1234!');
    await tester.tap(find.byKey(loginButtonKey));
    await settle(tester);
    expect(currentLocation(tester), AppRoutes.home);
    await tester.tap(find.text('마이페이지'));
    await settle(tester);
    await tester.tap(find.byKey(myRatingsEntryKey));
    await settle(tester);
    expect(find.byKey(myRatingsEmptyKey), findsOneWidget);
    expect(find.text('파이트 클럽'), findsNothing);
  });
}
