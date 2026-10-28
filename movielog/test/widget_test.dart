import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/genre_filter_sheet.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_grid.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_states.dart';
import 'package:movielog/features/movies/presentation/widgets/retry_dialog.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/features/start/presentation/start_screen.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

import 'support.dart';

Finder dialogStar(int index) => find
    .descendant(
      of: find.byType(MovieRatingDialog),
      matching: find.byIcon(Icons.star_rounded),
    )
    .at(index);

void main() {
  // 폰 크기 화면에서 테스트한다.
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

  Widget app(String location) => MovieLogApp(
    initialLocation: location,
    tmdbService: tmdb,
    movieLogApiService: api,
    preferences: MemoryMoviePreferences(),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  setUp(() {
    tmdb = FakeTmdbMovieService();
    api = FakeMovieLogApiService();
  });

  testWidgets('회원가입: 서버 중복 확인을 통과해야 가입 버튼이 켜지고 홈으로 간다', (tester) async {
    await tester.pumpWidget(app(AppRoutes.start));
    await tester.tap(find.byKey(startButtonKey));
    await settle(tester);

    FilledButton signUp() =>
        tester.widget<FilledButton>(find.byKey(signUpButtonKey));

    await tester.enterText(find.byKey(nicknameFieldKey), '수현');
    await tester.enterText(find.byKey(emailFieldKey), 'kevin@umc.com');
    await tester.enterText(find.byKey(passwordFieldKey), 'password1234');
    await tester.tap(find.byKey(termsCheckboxKey));
    await tester.pump();
    expect(signUp().onPressed, isNull); // 아직 중복 확인 전

    await tester.tap(find.byKey(nicknameCheckButtonKey));
    await settle(tester);
    expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);

    await tester.enterText(find.byKey(nicknameFieldKey), '케빈');
    await tester.pump();
    await tester.tap(find.byKey(nicknameCheckButtonKey));
    await settle(tester);
    expect(find.text('사용할 수 있는 닉네임이에요.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(emailCheckButtonKey));
    await tester.tap(find.byKey(emailCheckButtonKey));
    await settle(tester);
    expect(find.text('사용할 수 있는 이메일이에요.'), findsOneWidget);
    expect(api.checkedNicknames, ['수현', '케빈']);
    expect(api.checkedEmails, ['kevin@umc.com']);
    expect(signUp().onPressed, isNotNull);

    await tester.ensureVisible(find.byKey(signUpButtonKey));
    await tester.tap(find.byKey(signUpButtonKey));
    await settle(tester);
    expect(find.text('인기 영화'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('닉네임 13자는 화면에서 먼저 막아 서버에 묻지 않는다', (tester) async {
    await tester.pumpWidget(app(AppRoutes.signUp));
    await tester.enterText(find.byKey(nicknameFieldKey), '가' * 13);
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(nicknameCheckButtonKey))
          .onPressed,
      isNull,
    );
  });

  testWidgets('홈: Popular 앞 5개만 표시, 요청은 한 번, 카드 → 상세(TMDB id)', (tester) async {
    await tester.pumpWidget(app(AppRoutes.home));
    expect(find.bySemanticsLabel('인기 영화를 불러오는 중'), findsOneWidget);
    await settle(tester);

    expect(find.byKey(const Key('featured-100')), findsOneWidget);
    // 가로 목록을 끝까지 넘겨 5번째(id 104)까지 있고 6번째(105)는 없는지 본다.
    final list = find.byKey(const Key('popularList'));
    await tester.ensureVisible(list);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('movieCard-104')),
      list,
      const Offset(-200, 0),
    );
    await tester.drag(list, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movieCard-104')), findsOneWidget);
    expect(find.byKey(const Key('movieCard-105')), findsNothing);
    expect(tmdb.popularCalls, 1);
    await tester.drag(list, const Offset(2000, 0));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('상세보기'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('상세보기'));
    await settle(tester);
    expect(find.text('TMDB 영화 ID 100'), findsOneWidget);
    expect(tmdb.movieCalls, isEmpty); // 목록의 DTO를 넘겨받아 다시 조회하지 않는다

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('인기 영화'), findsOneWidget);
    expect(tmdb.popularCalls, 1); // 돌아와도 다시 요청하지 않는다
  });

  testWidgets('상세: 평점 Dialog 결과가 TMDB id를 movieId로 가진다', (tester) async {
    tmdb.moviesById[550] = movie(550, title: '파이트 클럽', overview: '');
    await tester.pumpWidget(app(AppRoutes.movieDetail(550)));
    await settle(tester);
    // 주소로 바로 열면 Movie Details를 조회한다.
    expect(tmdb.movieCalls, [550]);
    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(find.text('줄거리 정보가 없어요.'), findsOneWidget);

    await tester.tap(find.byKey(favoriteButtonKey));
    await tester.pump();
    expect(find.text('즐겨찾기에 추가했어요.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(rateButtonKey));
    await tester.tap(find.byKey(rateButtonKey));
    await settle(tester);
    await tester.tap(dialogStar(3));
    await tester.pump();
    expect(find.text('4점'), findsOneWidget);
    await tester.tap(find.byKey(saveRatingButtonKey));
    await settle(tester);
    expect(find.textContaining('movieId 550에 4점'), findsOneWidget);
    expect(find.text('내 평점 4점'), findsOneWidget);
  });

  testWidgets('목록: Loading → Success 30편, 장르 Chip은 with_genres 재요청', (
    tester,
  ) async {
    await tester.pumpWidget(app(AppRoutes.movies));
    await tester.pump();
    expect(find.byType(MovieListLoading), findsOneWidget);
    await settle(tester);
    expect(find.byType(MovieGrid), findsOneWidget);
    expect(find.text('전체 · 30편'), findsOneWidget);
    expect(find.text('액션'), findsWidgets);

    await tester.tap(find.byKey(const Key('genreChip-18')));
    await tester.pump();
    // 요청 중: Loading이고 Chip은 눌리지 않는다.
    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('genreChip-12')))
          .onSelected,
      isNull,
    );
    await settle(tester);
    expect(find.text('드라마 · 30편'), findsOneWidget);
    expect(tmdb.discoverCalls.last.genreIds, [18]);
    expect(
      tmdb.discoverCalls
          .where((c) => c.genreIds?.contains(18) ?? false)
          .first
          .page,
      1,
    );

    await tester.tap(find.byKey(allGenreChipKey));
    await settle(tester);
    expect(find.text('전체 · 30편'), findsOneWidget);
    expect(tmdb.discoverCalls.last.genreIds, isEmpty);
  });

  testWidgets('목록: Empty 안내', (tester) async {
    tmdb
      ..perPage = 0
      ..totalPages = 0;
    await tester.pumpWidget(app(AppRoutes.movies));
    await settle(tester);
    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
  });

  testWidgets('목록: Error → 다시 시도 → Success', (tester) async {
    tmdb.failDiscover = true;
    await tester.pumpWidget(app(AppRoutes.movies));
    await settle(tester);
    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);

    tmdb.failDiscover = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.byType(MovieListLoading), findsOneWidget);
    await settle(tester);
    expect(find.text('전체 · 30편'), findsOneWidget);
  });

  testWidgets('목록: 새로고침 실패 시 목록 유지 + 재시도 Dialog → 다시 시도로 교체', (tester) async {
    await tester.pumpWidget(app(AppRoutes.movies));
    await settle(tester);
    expect(find.byKey(const Key('movieCard-1')), findsOneWidget);

    tmdb.failDiscover = true;
    await tester.drag(find.byType(MovieGrid), const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    expect(find.byType(RetryDialog), findsOneWidget);
    // 최근 성공 목록은 그대로 화면에 남아 있다.
    expect(find.byKey(const Key('movieCard-1')), findsOneWidget);

    tmdb.failDiscover = false;
    tmdb.discoverPage = (page, genreIds) =>
        (FakeTmdbMovieService()
              ..perPage = 20
              ..totalPages = 1)
            .discoverPageFor(page, genreIds, offset: 500);
    final before = tmdb.discoverCalls.length;
    await tester.tap(find.byKey(retryDialogRetryKey));
    await settle(tester);
    expect(find.byType(RetryDialog), findsNothing);
    expect(tmdb.discoverCalls[before].page, 1);
    expect(find.byKey(const Key('movieCard-501')), findsOneWidget);
    expect(find.text('전체 · 20편'), findsOneWidget);
  });

  testWidgets('목록: 재시도 Dialog에서 취소하면 기존 목록 그대로', (tester) async {
    await tester.pumpWidget(app(AppRoutes.movies));
    await settle(tester);
    tmdb.failDiscover = true;
    await tester.drag(find.byType(MovieGrid), const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    await tester.tap(find.byKey(retryDialogCancelKey));
    await settle(tester);
    expect(find.byType(RetryDialog), findsNothing);
    expect(find.text('전체 · 30편'), findsOneWidget);
  });

  testWidgets('목록: BottomSheet 다중 선택 → 장르 ID 목록으로 요청', (tester) async {
    await tester.pumpWidget(app(AppRoutes.movies));
    await settle(tester);
    await tester.tap(find.byKey(filterButtonKey));
    await settle(tester);
    await tester.tap(find.byKey(const Key('genreCheckbox-28')));
    await tester.tap(find.byKey(const Key('genreCheckbox-12')));
    await tester.pump();
    expect(find.text('전체 · 30편'), findsOneWidget); // 확인 전에는 그대로
    await tester.tap(find.byKey(applyFilterButtonKey));
    await settle(tester);
    expect(tmdb.discoverCalls.last.genreIds, [28, 12]);
    expect(find.text('액션, 모험 · 30편'), findsOneWidget);

    // 아무것도 고르지 않고 확인 → with_genres 없이 전체
    await tester.tap(find.byKey(filterButtonKey));
    await settle(tester);
    await tester.tap(find.text('전체 해제'));
    await tester.pump();
    await tester.tap(find.byKey(applyFilterButtonKey));
    await settle(tester);
    expect(tmdb.discoverCalls.last.genreIds, isEmpty);
  });

  testWidgets('포스터를 받는 중에는 빈 칸 대신 회색 자리를 둔다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TmdbPosterImage(posterPath: '/a.jpg', width: 100, height: 150),
      ),
    );
    // 테스트 HttpClient는 응답을 바로 주지 않으므로 아직 첫 프레임 전이다.
    expect(find.byKey(posterLoadingKey), findsOneWidget);
    expect(find.byKey(posterPlaceholderKey), findsNothing);
  });

  testWidgets('포스터가 null이거나 로드에 실패하면 placeholder', (tester) async {
    tmdb.discoverPage = (page, genreIds) =>
        (FakeTmdbMovieService()
              ..perPage = 2
              ..totalPages = 1)
            .discoverPageFor(page, genreIds, posterPath: null);
    await tester.pumpWidget(app(AppRoutes.movies));
    await settle(tester);
    expect(find.byKey(posterPlaceholderKey), findsNWidgets(2));
    expect(find.text('포스터 없음'), findsNWidgets(2));
  });

  testWidgets('마이페이지: 자체 백엔드 평점 목록과 TMDB 제목', (tester) async {
    tmdb.moviesById
      ..[550] = movie(550, title: '파이트 클럽')
      ..[155] = movie(155, title: '다크 나이트');
    await tester.pumpWidget(app(AppRoutes.my));
    await settle(tester);
    expect(find.text('다크 나이트'), findsOneWidget);
    expect(find.text('파이트 클럽'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);
    expect(find.textContaining('movieId 155'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('마이페이지: 서버가 꺼져 있으면 안내와 다시 시도', (tester) async {
    api.fail = true;
    await tester.pumpWidget(app(AppRoutes.my));
    await settle(tester);
    expect(find.byKey(myRatingsRetryKey), findsOneWidget);
    api.fail = false;
    await tester.tap(find.byKey(myRatingsRetryKey));
    await settle(tester);
    expect(find.text('최고의 영화!'), findsOneWidget);
  });

  testWidgets('NavigationBar로 탭을 전환한다', (tester) async {
    await tester.pumpWidget(app(AppRoutes.home));
    await settle(tester);
    await tester.tap(find.text('영화').last);
    await settle(tester);
    expect(find.text('전체 · 30편'), findsOneWidget);
    await tester.tap(find.text('마이페이지').last);
    await settle(tester);
    expect(find.text('내가 남긴 평점'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });
}
