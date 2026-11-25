import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/my_page/presentation/my_ratings_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
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

  late FakeTmdbMovieService tmdb;
  late FakeMovieLogApiService api;

  setUp(() {
    tmdb = FakeTmdbMovieService(delay: Duration.zero);
    api = FakeMovieLogApiService();
    tmdb.moviesById
      ..[550] = movie(550, title: '파이트 클럽')
      ..[155] = movie(155, title: '다크 나이트');
  });

  /// 회원가입을 마친 상태(memberId 1)로 시작한다. session을 null로 주면 가입 전 상태다.
  Future<void> open(
    WidgetTester tester,
    String location, {
    LearningMemberSession? session,
    bool signedUp = true,
  }) => tester.pumpWidget(
    MovieLogApp(
      initialLocation: location,
      tmdbService: tmdb,
      movieLogApiService: api,
      preferences: MemoryMoviePreferences(),
      session: signedUp
          ? (session ?? (LearningMemberSession()..setMemberId(1)))
          : null,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('마이페이지의 진입 행을 누르면 하단 NavigationBar 없는 자식 화면이 열린다', (
    tester,
  ) async {
    await open(tester, AppRoutes.my);
    await settle(tester);
    // 마이페이지에는 하단 NavigationBar가 있고 평점 목록 자체는 없다.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(myRatingsEntryKey), findsOneWidget);
    expect(find.text('내가 등록한 평점'), findsOneWidget);
    expect(find.text('파이트 클럽'), findsNothing);
    expect(api.ratingMemberIds, isEmpty); // 진입하기 전에는 조회하지 않는다

    await tester.tap(find.byKey(myRatingsEntryKey));
    await settle(tester);

    // root Navigator 위에 열리므로 NavigationBar가 가려진다.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('내가 등록한 평점'), findsOneWidget); // AppBar 제목
    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(api.ratingMemberIds, [1]); // 학습용 memberId 1

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

  testWidgets('주소로 /my/ratings를 바로 열어도 같은 화면이다', (tester) async {
    await open(tester, AppRoutes.myRatings);
    await settle(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('다크 나이트'), findsOneWidget);
  });

  testWidgets('Loading → Success: 점수·후기·등록일·TMDB 제목이 함께 보인다', (tester) async {
    api.gate = Completer<void>();
    await open(tester, AppRoutes.myRatings);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(myRatingsLoadingKey), findsOneWidget);
    expect(find.byKey(myRatingsErrorKey), findsNothing);
    expect(find.byKey(myRatingsEmptyKey), findsNothing);

    api.gate!.complete();
    await settle(tester);

    expect(find.byKey(myRatingsLoadingKey), findsNothing);
    expect(find.text('다크 나이트'), findsOneWidget);
    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(find.text('다시 봐도 명작'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(find.text('★★★★★  5점'), findsOneWidget);
    expect(find.textContaining('movieId 155'), findsOneWidget);
    expect(find.textContaining('2026.10.28'), findsNWidgets(2));
    expect(find.text('4.5'), findsOneWidget); // 평균
    expect(find.byKey(myRatingsNoticeKey), findsNothing);
    // 로그인한 본인이 아니라 학습용 회원의 공개 조회임을 알린다.
    expect(find.textContaining('학습용 회원 #1'), findsOneWidget);
  });

  testWidgets('Empty: 평점이 없는 회원은 빈 상태이며 오류가 아니다', (tester) async {
    api.ratings = const [];
    await open(tester, AppRoutes.myRatings);
    await settle(tester);
    expect(find.byKey(myRatingsEmptyKey), findsOneWidget);
    expect(find.text('아직 남긴 평점이 없어요.'), findsOneWidget);
    expect(find.byKey(myRatingsErrorKey), findsNothing);
    expect(find.byKey(myRatingsRetryKey), findsNothing);
  });

  testWidgets('Error: 404와 통신 실패는 다른 문구이고 다시 시도하면 Success가 된다', (tester) async {
    api.ratingsStatus = 404;
    await open(tester, AppRoutes.myRatings);
    await settle(tester);
    expect(find.byKey(myRatingsErrorKey), findsOneWidget);
    expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    expect(find.byKey(myRatingsEmptyKey), findsNothing);

    api.ratingsStatus = null;
    api.fail = true;
    await tester.tap(find.byKey(myRatingsRetryKey));
    await settle(tester);
    expect(find.text('존재하지 않는 회원입니다.'), findsNothing);
    expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);

    api.fail = false;
    await tester.tap(find.byKey(myRatingsRetryKey));
    await settle(tester);
    expect(find.byKey(myRatingsErrorKey), findsNothing);
    expect(find.text('최고의 영화!'), findsOneWidget);
  });

  testWidgets('후기가 없는 평점(comment: null)은 후기 줄을 그리지 않는다', (tester) async {
    api.ratings = [memberRating(1, 550, score: 3, comment: null)];
    await open(tester, AppRoutes.myRatings);
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
    tmdb.notFoundMovieIds.add(155);
    await open(tester, AppRoutes.myRatings);
    await settle(tester);

    expect(find.byKey(myRatingsErrorKey), findsNothing);
    expect(find.text('파이트 클럽'), findsOneWidget);
    // ratingId 2 = movieId 155. 이 타일만 제목·포스터가 placeholder다.
    final missing = find.byKey(const Key('ratingTile-2'));
    expect(
      find.descendant(of: missing, matching: find.text('영화 정보 없음')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: missing, matching: find.byKey(posterPlaceholderKey)),
      findsOneWidget,
    );
    expect(find.text('영화 정보 없음'), findsOneWidget);
    // 평점 자체와 movieId는 그대로 보인다.
    expect(find.text('다시 봐도 명작'), findsOneWidget);
    expect(find.textContaining('movieId 155'), findsOneWidget);
    expect(find.byKey(myRatingsNoticeKey), findsOneWidget);
    expect(find.textContaining('일부 영화 정보를 가져오지 못해'), findsOneWidget);
  });

  testWidgets('평점 항목을 누르면 TMDB id로 영화 상세가 열리고 뒤로 가면 목록으로 돌아온다', (tester) async {
    await open(tester, AppRoutes.myRatings);
    await settle(tester);
    tmdb.movieCalls.clear();

    await tester.tap(find.byKey(const Key('ratingTile-1')));
    await settle(tester);
    expect(find.text('TMDB 영화 ID 550'), findsOneWidget);
    expect(tmdb.movieCalls, isEmpty); // 넘겨받은 영화는 다시 조회하지 않는다

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('내가 등록한 평점'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
  });
}
