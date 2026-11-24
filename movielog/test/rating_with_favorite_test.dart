import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/favorite_button.dart';
import 'package:movielog/features/my_page/presentation/my_ratings_screen.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';

import 'support.dart';

Finder _star(int index) => find
    .descendant(
      of: find.byType(MovieRatingDialog),
      matching: find.byIcon(Icons.star_rounded),
    )
    .at(index);

/// 영화 상세의 "평점 남기기" Dialog에서 평점과 즐겨찾기를 한 번에 저장하는 흐름(Challenge C).
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
  const movieId = 550;

  setUp(() {
    h = AppHarness();
    h.tmdb.moviesById[movieId] = movie(movieId, title: '파이트 클럽');
  });

  Future<void> openDetail(WidgetTester tester) async {
    await tester.pumpWidget(h.app(initialLocation: AppRoutes.movieDetail(movieId)));
    await settle(tester);
    expect(find.text('파이트 클럽'), findsOneWidget);
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(rateButtonKey));
    await tester.tap(find.byKey(rateButtonKey));
    await settle(tester);
    expect(find.byType(MovieRatingDialog), findsOneWidget);
  }

  Future<void> fill(
    WidgetTester tester, {
    int star = 3,
    String comment = '반전이 좋았다',
    bool check = true,
  }) async {
    await tester.tap(_star(star));
    await tester.pump();
    await tester.enterText(find.byKey(ratingCommentFieldKey), comment);
    if (check) {
      await tester.tap(find.byKey(addToFavoriteCheckboxKey));
    }
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(saveRatingButtonKey));
    await settle(tester);
  }

  Finder filledBookmark() => find.byIcon(Icons.bookmark);
  Finder emptyBookmark() => find.byIcon(Icons.bookmark_border);

  group('체크박스가 보이는 조건', () {
    testWidgets('① 아직 즐겨찾기하지 않은 영화면 보이고 기본은 해제다', (tester) async {
      await openDetail(tester);
      await openDialog(tester);
      expect(find.byKey(addToFavoriteCheckboxKey), findsOneWidget);
      expect(find.text('즐겨찾기에도 추가'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(addToFavoriteCheckboxKey))
            .value,
        isFalse,
      );
    });

    testWidgets('② 이미 즐겨찾기한 영화면 보이지 않는다', (tester) async {
      h.favoriteApi.seed([movieId]);
      await openDetail(tester);
      await openDialog(tester);
      expect(find.byKey(addToFavoriteCheckboxKey), findsNothing);
    });

    testWidgets('③ 즐겨찾기 여부를 아직 모르면(조회 실패) 보이지 않는다', (tester) async {
      h.favoriteApi.failures['check'] = networkFailure('/favorites/550');
      await openDetail(tester);
      await openDialog(tester);
      expect(find.byKey(addToFavoriteCheckboxKey), findsNothing);
    });

    testWidgets('평점 수정 Dialog에는 체크박스가 없다', (tester) async {
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.myRatings));
      await settle(tester);
      seedRatings(tester, h, [memberRating(1, movieId, score: 5, comment: '최고')]);
      await settle(tester);
      await tester.tap(find.byKey(const Key('ratingEditButton-1')));
      await settle(tester);
      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.byKey(addToFavoriteCheckboxKey), findsNothing);
      expect(find.byType(MyRatingsScreen), findsOneWidget);
    });
  });

  group('요청 분기', () {
    testWidgets('즐겨찾기 안 한 영화 + 체크: POST /movie-records 한 번(addToFavorites=true), /ratings·/favorites는 부르지 않는다', (
      tester,
    ) async {
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      await save(tester);

      expect(h.movieRecordApi.requests, hasLength(1));
      expect(h.movieRecordApi.requests.single.toJson(), {
        'movieId': movieId,
        'score': 4,
        'comment': '반전이 좋았다',
        'addToFavorites': true,
      });
      expect(h.ratingApi.createdRequests, isEmpty);
      expect(h.favoriteApi.addCalls, isEmpty);
      expect(h.favoriteApi.isFavoriteOf(movieId), isTrue);
    });

    testWidgets('성공: Dialog가 닫힌 뒤 "평점을 저장했습니다." Snackbar가 보이고, 북마크는 서버 값으로 다시 맞춰진다', (
      tester,
    ) async {
      await openDetail(tester);
      expect(emptyBookmark(), findsOneWidget);
      final checksBefore = h.favoriteApi.checkCalls.length;
      await openDialog(tester);
      await fill(tester);
      await save(tester);

      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      expect(
        h.favoriteApi.checkCalls.length,
        greaterThan(checksBefore),
        reason: '저장 뒤 GET /favorites/{movieId}로 서버 값을 다시 받는다',
      );
      await settle(tester);
      expect(filledBookmark(), findsOneWidget);
      expect(find.byKey(myRatingLabelKey), findsOneWidget);
      // 응답의 평점은 이번 세션 목록에 들어간다.
      expect(sessionOf(tester).ratings.single.movieId, movieId);
    });

    testWidgets('즐겨찾기 안 한 영화 + 체크 해제: addToFavorites=false로 저장하고 북마크는 비어 있다', (tester) async {
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester, check: false);
      await save(tester);
      expect(h.movieRecordApi.requests.single.addToFavorites, isFalse);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      expect(emptyBookmark(), findsOneWidget);
      expect(h.favoriteApi.isFavoriteOf(movieId), isFalse);
    });

    testWidgets('이미 즐겨찾기한 영화: 기존 POST /ratings로 저장하고 /movie-records는 부르지 않는다', (tester) async {
      h.favoriteApi.seed([movieId]);
      await openDetail(tester);
      await openDialog(tester);
      await tester.tap(_star(4));
      await tester.pump();
      await save(tester);

      expect(h.ratingApi.createdRequests, hasLength(1));
      expect(h.ratingApi.createdRequests.single.toJson(), {
        'movieId': movieId,
        'score': 5,
      });
      expect(h.movieRecordApi.requests, isEmpty);
      expect(find.textContaining('평점을 등록했습니다'), findsOneWidget);
      expect(filledBookmark(), findsOneWidget);
    });
  });

  group('실패: 코드에 따라 Dialog를 열어 두거나 닫는다', () {
    testWidgets('COMMON400: Dialog를 열어 둔 채 이유를 보여 주고 별점·코멘트·체크를 유지한다', (tester) async {
      h.movieRecordApi.failure = apiFailure(
        '/movie-records',
        400,
        code: 'COMMON400',
        message: '요청 값이 올바르지 않습니다.',
      );
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester, star: 1, comment: '꼭 유지해야 함');
      await save(tester);

      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.byKey(ratingDialogErrorKey), findsOneWidget);
      expect(find.text('요청 값이 올바르지 않습니다.'), findsOneWidget);
      expect(find.text('2점'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(ratingCommentFieldKey)).controller!.text,
        '꼭 유지해야 함',
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(addToFavoriteCheckboxKey))
            .value,
        isTrue,
      );
      expect(find.text('평점을 저장했습니다.'), findsNothing);
      expect(h.favoriteApi.isFavoriteOf(movieId), isFalse);
    });

    testWidgets('네트워크 실패: Dialog를 열어 두고 입력을 유지하며 다시 저장하면 성공한다', (tester) async {
      h.movieRecordApi.failure = networkFailure('/movie-records');
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      await save(tester);
      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.textContaining('네트워크'), findsOneWidget);
      expect(find.text('4점'), findsOneWidget);
      expect(h.storage.token, isNotNull, reason: '로그아웃하지 않는다');

      h.movieRecordApi.failure = null;
      await save(tester);
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      expect(h.movieRecordApi.requests, hasLength(2));
    });

    testWidgets('timeout: 자동 재시도 없이 Dialog를 열어 두고, 다시 누르면 이미 저장됐다는 RATING409_1로 닫힌다', (tester) async {
      h.movieRecordApi.timeoutAfterApply = true;
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      await save(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(h.movieRecordApi.requests, hasLength(1), reason: '자동 재시도 없음');
      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.textContaining('응답이 늦어'), findsOneWidget);

      h.movieRecordApi.timeoutAfterApply = false;
      await save(tester);
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      // 서버에는 처음 요청이 저장되어 있으므로 북마크도 서버 값(true)으로 맞춰진다.
      await settle(tester);
      expect(filledBookmark(), findsOneWidget);
    });

    testWidgets('RATING409_1: Dialog를 닫고 서버 message를 Snackbar로 안내한다', (tester) async {
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      h.ratingApi.serverRatings[9] = memberRating(9, movieId); // 그 사이 다른 기기에서 평점을 남김
      await save(tester);
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(h.favoriteApi.isFavoriteOf(movieId), isFalse);
      expect(emptyBookmark(), findsOneWidget);
    });

    testWidgets('FAVORITE409_1: Dialog를 닫고 평점도 저장되지 않았다고 알리며, 북마크를 서버 값으로 맞춘다', (tester) async {
      await openDetail(tester);
      expect(emptyBookmark(), findsOneWidget);
      await openDialog(tester);
      await fill(tester);
      h.favoriteApi.seed([movieId]); // 화면은 모르는 사이에 이미 즐겨찾기됨
      await save(tester);

      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.textContaining('이미 즐겨찾기한 영화입니다.'), findsOneWidget);
      expect(find.textContaining('평점은 저장되지 않았어요'), findsOneWidget);
      expect(h.ratingApi.serverRatings, isEmpty, reason: '평점도 저장되지 않는다');
      await settle(tester);
      expect(filledBookmark(), findsOneWidget, reason: '서버 값(즐겨찾기됨)으로 다시 맞춤');
      expect(find.byKey(myRatingLabelKey), findsNothing);
    });

    testWidgets('MEMBER404_1: Dialog를 닫고 서버 message를 Snackbar로 안내한다', (tester) async {
      h.movieRecordApi.failure = apiFailure(
        '/movie-records',
        404,
        code: 'MEMBER404_1',
        message: '회원을 찾을 수 없습니다.',
      );
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      await save(tester);
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('회원을 찾을 수 없습니다.'), findsOneWidget);
    });

    testWidgets('토큰이 만료되면(AUTH401_3) 로그인 화면으로 간다', (tester) async {
      h.movieRecordApi.failure = apiFailure(
        '/movie-records',
        401,
        code: 'AUTH401_3',
        message: '토큰 만료',
      );
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      await save(tester);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
    });

    testWidgets('저장 중에는 Dialog가 닫히지 않고 요청은 한 번이다', (tester) async {
      h.movieRecordApi.gate = Completer<void>();
      await openDetail(tester);
      await openDialog(tester);
      await fill(tester);
      await tester.tap(find.byKey(saveRatingButtonKey));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(saveRatingButtonKey), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(h.movieRecordApi.requests, hasLength(1));
      h.movieRecordApi.gate!.complete();
      await settle(tester);
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
    });
  });

  testWidgets('저장 뒤 북마크를 눌러 해제할 수 있고 상세 화면이 그대로 유지된다', (tester) async {
    await openDetail(tester);
    await openDialog(tester);
    await fill(tester);
    await save(tester);
    await settle(tester);
    expect(filledBookmark(), findsOneWidget);
    await tester.tap(find.byKey(favoriteButtonKey));
    await settle(tester);
    expect(emptyBookmark(), findsOneWidget);
    expect(find.byType(MovieDetailScreen), findsOneWidget);
  });
}
