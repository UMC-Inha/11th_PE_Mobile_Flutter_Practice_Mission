import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/features/my_page/presentation/my_ratings_screen.dart';
import 'package:movielog/features/my_page/presentation/widgets/delete_rating_dialogs.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/view_models/learning_member_session.dart';

import 'support.dart';

Finder _editButton(int id) => find.byKey(Key('ratingEditButton-$id'));
Finder _deleteButton(int id) => find.byKey(Key('ratingDeleteButton-$id'));
Finder _checkbox(int id) => find.byKey(Key('ratingCheckbox-$id'));
Finder _tile(int id) => find.byKey(Key('ratingTile-$id'));
Finder _star(int index) => find
    .descendant(
      of: find.byType(MovieRatingDialog),
      matching: find.byIcon(Icons.star_rounded),
    )
    .at(index);

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
      ..[155] = movie(155, title: '다크 나이트')
      ..[27205] = movie(27205, title: '인셉션')
      ..[680] = movie(680, title: '펄프 픽션');
  });

  Future<void> open(WidgetTester tester, {bool signedUp = true}) async {
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: AppRoutes.myRatings,
        tmdbService: tmdb,
        movieLogApiService: api,
        preferences: MemoryMoviePreferences(),
        session: signedUp ? (LearningMemberSession()..setMemberId(101)) : null,
      ),
    );
    await settle(tester);
  }

  /// 영화 4편의 평점 4개(ratingId 4·3·2·1)로 시작한다.
  void fourRatings() {
    api.ratings = [
      memberRating(4, 155, score: 3, comment: null),
      memberRating(3, 550, score: 5, comment: '최고'),
      memberRating(2, 27205, score: 4, comment: '꿈속의 꿈'),
      memberRating(1, 680, score: 2, comment: '그저 그랬다'),
    ];
  }

  /// 시간을 일정만큼만 흘린다. 로딩 인디케이터가 도는 동안에는 pumpAndSettle을 쓸 수 없다.
  Future<void> pumpFor(WidgetTester tester, [int ms = 400]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
  }

  /// 시스템 뒤로가기를 Router에 보낸다. 화면이 막으면 true.
  Future<bool> systemBack(WidgetTester tester) {
    final context = tester.element(find.byKey(myRatingsPopScopeKey));
    return Router.of(context).backButtonDispatcher!
        .invokeCallback(Future<bool>.value(false));
  }

  ElevatedButton elevated(WidgetTester tester, Key key) =>
      tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(ElevatedButton),
        ),
      );

  testWidgets('회원가입 전에는 평점을 조회하지 않고 가입을 안내한다', (tester) async {
    await open(tester, signedUp: false);
    expect(find.text('학습용 회원가입이 필요합니다.'), findsOneWidget);
    expect(api.fetchCalls, 0);
  });

  testWidgets('조회는 가입한 회원의 memberId로 하고, 카드마다 수정·삭제 버튼이 있다', (tester) async {
    await open(tester);
    expect(api.ratingMemberIds, [101]);
    for (final id in [1, 2]) {
      expect(_editButton(id), findsOneWidget);
      expect(_deleteButton(id), findsOneWidget);
      expect(_checkbox(id), findsNothing);
    }
    expect(find.byKey(myRatingsEditToggleKey), findsOneWidget);
    expect(find.text('편집'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  group('수정', () {
    testWidgets('수정 버튼을 누르면 기존 별점·코멘트가 채워진 Dialog가 열리고, 저장하면 목록이 갱신된다', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(_editButton(2)); // 다크 나이트: 4점 '다시 봐도 명작'
      await settle(tester);

      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.text('평점 수정하기'), findsOneWidget);
      expect(find.text('다크 나이트'), findsWidgets);
      expect(find.text('4점'), findsWidgets);
      final field = tester.widget<TextField>(find.byKey(ratingCommentFieldKey));
      expect(field.controller!.text, '다시 봐도 명작');

      await tester.tap(_star(1)); // 2점으로
      await tester.pump();
      await tester.enterText(find.byKey(ratingCommentFieldKey), '다시 보니 별로');
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);

      // PATCH에는 score와 comment를 항상 실어 보낸다.
      expect(api.updatedRatings.single.ratingId, 2);
      expect(api.updatedRatings.single.memberId, 101);
      expect(api.updatedRatings.single.request.toJson(), {
        'score': 2,
        'comment': '다시 보니 별로',
      });
      // 저장 성공 뒤 서버 목록을 다시 조회했다.
      expect(api.fetchCalls, 2);
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('다시 보니 별로'), findsOneWidget);
      expect(find.text('★★☆☆☆  2점'), findsOneWidget);
      expect(find.text('평점을 수정했어요.'), findsOneWidget);
    });

    testWidgets('comment가 null인 평점은 코멘트 칸이 빈 채로 열린다', (tester) async {
      fourRatings();
      await open(tester);
      await tester.tap(_editButton(4));
      await settle(tester);
      final field = tester.widget<TextField>(find.byKey(ratingCommentFieldKey));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('코멘트를 모두 지우고 저장하면 후기가 사라진다', (tester) async {
      await open(tester);
      await tester.tap(_editButton(1));
      await settle(tester);
      await tester.enterText(find.byKey(ratingCommentFieldKey), '');
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);
      expect(api.updatedRatings.single.request.toJson()['comment'], isNull);
      expect(find.text('최고의 영화!'), findsNothing);
    });

    testWidgets('취소하면 요청도 갱신도 없다', (tester) async {
      await open(tester);
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.tap(find.byKey(cancelRatingButtonKey));
      await settle(tester);
      expect(api.updatedRatings, isEmpty);
      expect(api.fetchCalls, 1);
      expect(find.text('평점을 수정했어요.'), findsNothing);
    });

    testWidgets('저장 실패: Dialog에 서버 문구가 보이고 입력은 유지되며, 목록은 그대로다', (tester) async {
      api.failures['updateRating'] = FakeMovieLogApiService.badResponse(
        '/members/101/ratings/2',
        400,
        message: '별점은 5점 이하여야 합니다.',
      );
      await open(tester);
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.enterText(find.byKey(ratingCommentFieldKey), '고친 코멘트');
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);

      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.text('별점은 5점 이하여야 합니다.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(ratingCommentFieldKey))
            .controller!
            .text,
        '고친 코멘트',
      );
      expect(elevated(tester, saveRatingButtonKey).onPressed, isNotNull);
      expect(api.fetchCalls, 1); // 400은 다시 조회하지 않는다
      expect(find.text('평점을 수정했어요.'), findsNothing);

      // 닫으면 목록은 수정 전 그대로다.
      await tester.tap(find.byKey(cancelRatingButtonKey));
      await settle(tester);
      expect(find.text('다시 봐도 명작'), findsOneWidget);
    });

    testWidgets('저장은 성공했는데 목록 조회만 실패하면 Dialog는 성공으로 닫히고, 조회만 다시 시도한다', (
      tester,
    ) async {
      await open(tester);
      api.failFetchTimes = 1;
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.tap(_star(0)); // 1점
      await tester.pump();
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);

      // 저장은 끝났다: Dialog가 닫히고 성공 안내가 보인다.
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('평점을 수정했어요.'), findsOneWidget);
      expect(api.updatedRatings, hasLength(1));
      // 목록 영역에는 "조회만 다시" 안내와 재시도 버튼이 있다.
      expect(find.byKey(myRatingsRefreshWarningKey), findsOneWidget);
      expect(
        find.text('저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(myRatingsRetryKey));
      await settle(tester);
      // GET만 다시 나갔고 PATCH는 한 번뿐이다(같은 쓰기를 다시 보내 409가 나지 않는다).
      expect(api.updatedRatings, hasLength(1));
      expect(find.byKey(myRatingsRefreshWarningKey), findsNothing);
      expect(find.text('★☆☆☆☆  1점'), findsOneWidget);
    });
  });

  testWidgets('목록 조회가 실패한 상태에서는 평균 점수도 이전 값 대신 -로 보인다', (tester) async {
    await open(tester); // 시드: 4점·5점 → 평균 4.5
    expect(find.text('4.5'), findsOneWidget);
    api.failFetchTimes = 1;
    await tester.tap(_editButton(2));
    await settle(tester);
    await tester.tap(find.byKey(saveRatingButtonKey));
    await settle(tester);

    expect(find.byKey(myRatingsRefreshWarningKey), findsOneWidget);
    // "남긴 평점"이 -인데 평균만 낡은 값(4.5)을 보여 주면 서로 어긋난다.
    expect(find.text('4.5'), findsNothing);
    expect(find.text('-'), findsNWidgets(2));
  });

  group('삭제', () {
    testWidgets('삭제 버튼 → 확인 Dialog → 취소하면 삭제 요청이 나가지 않는다', (tester) async {
      await open(tester);
      await tester.tap(_deleteButton(1));
      await settle(tester);
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      await tester.tap(find.byKey(deleteRatingCancelKey));
      await settle(tester);
      expect(api.deletedRatings, isEmpty);
      expect(_tile(1), findsOneWidget);
    });

    testWidgets('확인하면 삭제되고 목록이 갱신되며, 마지막 항목을 지우면 Empty가 보인다', (tester) async {
      await open(tester);
      await tester.tap(_deleteButton(2));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);

      expect(api.deletedRatings.single, (memberId: 101, ratingId: 2));
      expect(_tile(2), findsNothing);
      expect(_tile(1), findsOneWidget);
      expect(find.text('평점을 삭제했어요.'), findsOneWidget);

      await tester.tap(_deleteButton(1));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);
      expect(find.byKey(myRatingsEmptyKey), findsOneWidget);
      expect(find.text('아직 남긴 평점이 없어요.'), findsOneWidget);
      expect(
        find.byKey(myRatingsEditToggleKey),
        findsNothing,
      ); // 평점이 없으면 편집할 수 없다
    });

    testWidgets('삭제 요청 중에는 Dialog가 유지되고 닫히지 않는다', (tester) async {
      await open(tester);
      api.writeGate = Completer<void>();
      await tester.tap(_deleteButton(1));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await pumpFor(tester);

      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(deleteRatingConfirmKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<PopScope>(find.byKey(deleteRatingPopScopeKey)).canPop,
        isFalse,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(deleteRatingCancelKey))
            .onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(4, 4)); // 바깥 탭
      await pumpFor(tester);
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);

      api.writeGate!.complete();
      await settle(tester);
      expect(find.text('평점을 삭제할까요?'), findsNothing);
      expect(_tile(1), findsNothing);
    });

    testWidgets('삭제 실패: Dialog에 서버 문구가 보이고 로딩이 풀려 다시 시도할 수 있다', (tester) async {
      api.failures['deleteRating'] = FakeMovieLogApiService.badResponse(
        '/members/101/ratings/1',
        403,
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await open(tester);
      await tester.tap(_deleteButton(1));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);

      expect(find.byKey(deleteRatingErrorKey), findsOneWidget);
      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(elevated(tester, deleteRatingConfirmKey).onPressed, isNotNull);

      api.failures.clear();
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);
      expect(_tile(1), findsNothing);
    });
  });

  group('편집 · 다중 선택 삭제 (Challenge)', () {
    testWidgets('편집을 누르면 수정·삭제 버튼 대신 체크박스가 보이고, 취소하면 기본 목록으로 돌아온다', (
      tester,
    ) async {
      fourRatings();
      await open(tester);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);

      for (final id in [1, 2, 3, 4]) {
        expect(_checkbox(id), findsOneWidget);
        expect(_editButton(id), findsNothing);
        expect(_deleteButton(id), findsNothing);
      }
      expect(find.text('취소'), findsOneWidget);
      // 선택이 없으면 하단 삭제 버튼은 비활성이다.
      expect(find.text('선택한 0개 삭제'), findsOneWidget);
      expect(elevated(tester, deleteSelectedButtonKey).onPressed, isNull);

      await tester.tap(_tile(3));
      await tester.tap(_tile(1));
      await settle(tester);
      expect(tester.widget<Checkbox>(_checkbox(3)).value, isTrue);
      expect(tester.widget<Checkbox>(_checkbox(2)).value, isFalse);
      expect(find.text('선택한 2개 삭제'), findsOneWidget);
      expect(elevated(tester, deleteSelectedButtonKey).onPressed, isNotNull);
      // 편집 중에는 카드를 눌러도 영화 상세로 이동하지 않는다.
      expect(find.byKey(myRatingsEditToggleKey), findsOneWidget);

      await tester.tap(find.byKey(myRatingsEditToggleKey)); // 취소
      await settle(tester);
      expect(_checkbox(3), findsNothing);
      expect(_editButton(3), findsOneWidget);
      expect(find.text('편집'), findsOneWidget);
      expect(find.byKey(deleteSelectedButtonKey), findsNothing);
    });

    testWidgets('확인하면 Dialog는 바로 닫히고, 삭제 중에는 로딩 오버레이와 이탈 방지가 걸린다', (
      tester,
    ) async {
      fourRatings();
      await open(tester);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(4));
      await tester.tap(_tile(2));
      await settle(tester);

      api.writeGate = Completer<void>();
      await tester.tap(find.byKey(deleteSelectedButtonKey));
      await settle(tester);
      expect(find.text('선택한 2개의 평점을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.byKey(deleteSelectedConfirmKey));
      await pumpFor(tester);

      // 단건 삭제와 달리 확인 Dialog는 요청 전에 이미 닫혔다.
      expect(find.text('선택한 2개의 평점을 삭제할까요?'), findsNothing);
      // 화면 위에 어두운 배리어와 인디케이터만 올라간다(문구·카드 없음).
      final overlay = find.byKey(myRatingsDeletingOverlayKey);
      expect(
        find.descendant(of: overlay, matching: find.byType(ModalBarrier)),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: overlay,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<PopScope>(find.byKey(myRatingsPopScopeKey)).canPop,
        isFalse,
      );
      expect(await systemBack(tester), isTrue, reason: '삭제가 끝나기 전에는 뒤로 갈 수 없다');
      expect(find.byKey(myRatingsPopScopeKey), findsOneWidget);
      // 편집 모드를 바꾸는 버튼도 잠긴다.
      expect(
        tester.widget<TextButton>(find.byKey(myRatingsEditToggleKey)).onPressed,
        isNull,
      );

      api.writeGate!.complete();
      await settle(tester);
      expect(api.deletedRatings.map((e) => e.ratingId), [4, 2]);
      expect(_tile(4), findsNothing);
      expect(_tile(2), findsNothing);
      expect(_tile(3), findsOneWidget);
      expect(find.text('2개의 평점을 삭제했어요.'), findsOneWidget);
      // 전부 지웠으니 기본 목록으로 돌아온다.
      expect(_editButton(3), findsOneWidget);
      expect(
        tester.widget<PopScope>(find.byKey(myRatingsPopScopeKey)).canPop,
        isTrue,
      );
    });

    testWidgets('삭제 중에는 하단 삭제 버튼도 비활성이라 두 번째 확인 Dialog가 열리지 않는다', (
      tester,
    ) async {
      fourRatings();
      await open(tester);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(4));
      await tester.tap(_tile(2));
      await settle(tester);
      expect(elevated(tester, deleteSelectedButtonKey).onPressed, isNotNull);

      api.writeGate = Completer<void>();
      await tester.tap(find.byKey(deleteSelectedButtonKey));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedConfirmKey));
      await pumpFor(tester);

      // 오버레이는 본문만 덮으므로, 하단 바는 스스로 비활성이어야 한다(라이브 브라우저에서 발견).
      expect(elevated(tester, deleteSelectedButtonKey).onPressed, isNull);
      await tester.tap(
        find.byKey(deleteSelectedButtonKey),
        warnIfMissed: false,
      );
      await pumpFor(tester);
      expect(find.text('선택한 2개의 평점을 삭제할까요?'), findsNothing);

      api.writeGate!.complete();
      await settle(tester);
      expect(api.deletedRatings, hasLength(2));
    });

    testWidgets('일부만 실패하면 성공한 항목만 사라지고, 실패 개수를 Snackbar로 알리며 선택은 유지된다', (
      tester,
    ) async {
      fourRatings();
      api.failDeleteIds.add(3);
      await open(tester);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(4));
      await tester.tap(_tile(3));
      await tester.tap(_tile(1));
      await settle(tester);

      await tester.tap(find.byKey(deleteSelectedButtonKey));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedConfirmKey));
      await settle(tester);

      expect(_tile(4), findsNothing);
      expect(_tile(1), findsNothing);
      expect(_tile(3), findsOneWidget); // 실패한 항목은 그대로 남는다
      expect(
        find.text('1개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'),
        findsOneWidget,
      );
      // 실패한 항목은 계속 선택되어 있어 바로 다시 시도할 수 있다.
      expect(tester.widget<Checkbox>(_checkbox(3)).value, isTrue);
      expect(find.text('선택한 1개 삭제'), findsOneWidget);
      expect(elevated(tester, deleteSelectedButtonKey).onPressed, isNotNull);
    });

    testWidgets('선택 확인 Dialog에서 취소하면 삭제 요청이 나가지 않는다', (tester) async {
      fourRatings();
      await open(tester);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(2));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedButtonKey));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedCancelKey));
      await settle(tester);

      expect(api.deletedRatings, isEmpty);
      expect(tester.widget<Checkbox>(_checkbox(2)).value, isTrue); // 선택은 그대로
    });
  });
}
