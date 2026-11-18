import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/my_page/presentation/my_ratings_screen.dart';
import 'package:movielog/features/my_page/presentation/widgets/delete_rating_dialogs.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';

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

  late AppHarness h;

  setUp(() {
    h = AppHarness();
    h.tmdb.moviesById
      ..[550] = movie(550, title: '파이트 클럽')
      ..[155] = movie(155, title: '다크 나이트')
      ..[27205] = movie(27205, title: '인셉션')
      ..[680] = movie(680, title: '펄프 픽션');
  });

  /// 저장된 토큰으로 세션을 복원해 /my/ratings를 열고, 평점 2개(ratingId 2·1)를 이번 세션에 심는다.
  /// 서버에는 "내 평점 목록" API가 없으므로 목록은 이번 로그인에서 등록한 평점으로만 채워진다.
  Future<void> open(WidgetTester tester, {bool four = false}) async {
    await tester.pumpWidget(h.app(initialLocation: AppRoutes.myRatings));
    await settle(tester);
    seedRatings(
      tester,
      h,
      four
          ? [
              memberRating(4, 155, score: 3, comment: null),
              memberRating(3, 550, score: 5, comment: '최고'),
              memberRating(2, 27205, score: 4, comment: '꿈속의 꿈'),
              memberRating(1, 680, score: 2, comment: '그저 그랬다'),
            ]
          : [
              memberRating(2, 155, score: 4, comment: '다시 봐도 명작'),
              memberRating(1, 550, score: 5, comment: '최고의 영화!'),
            ],
    );
    await settle(tester);
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

  testWidgets('카드마다 수정·삭제 버튼이 있고 편집 토글이 보이며 NavigationBar는 없다', (tester) async {
    await open(tester);
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

      // PATCH에는 score와 comment를 항상 실어 보낸다. 경로에 memberId가 없다(/ratings/{id}).
      expect(h.ratingApi.updatedCalls.single.ratingId, 2);
      expect(h.ratingApi.updatedCalls.single.request.toJson(), {
        'score': 2,
        'comment': '다시 보니 별로',
      });
      // 응답으로 받은 평점으로 목록을 바꾼다(다시 조회할 목록 API가 없다).
      expect(find.byType(MovieRatingDialog), findsNothing);
      expect(find.text('다시 보니 별로'), findsOneWidget);
      expect(find.text('★★☆☆☆  2점'), findsOneWidget);
      expect(find.text('평점을 수정했어요.'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget); // (2 + 5) / 2
    });

    testWidgets('comment가 null인 평점은 코멘트 칸이 빈 채로 열린다', (tester) async {
      await open(tester, four: true);
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
      expect(
        h.ratingApi.updatedCalls.single.request.toJson()['comment'],
        isNull,
      );
      expect(find.text('최고의 영화!'), findsNothing);
    });

    testWidgets('취소하면 요청도 갱신도 없다', (tester) async {
      await open(tester);
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.tap(find.byKey(cancelRatingButtonKey));
      await settle(tester);
      expect(h.ratingApi.updatedCalls, isEmpty);
      expect(find.text('평점을 수정했어요.'), findsNothing);
    });

    testWidgets('저장 실패: Dialog에 서버 문구가 보이고 입력은 유지되며, 목록은 그대로다', (tester) async {
      await open(tester);
      h.ratingApi.failures['update'] = apiFailure(
        '/ratings/2',
        400,
        code: 'RATING400_1',
        message: '별점은 5점 이하여야 합니다.',
      );
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
      expect(find.text('평점을 수정했어요.'), findsNothing);
      expect(authOf(tester).isSignedIn, isTrue); // 입력 오류는 로그아웃이 아니다

      // 닫으면 목록은 수정 전 그대로다.
      await tester.tap(find.byKey(cancelRatingButtonKey));
      await settle(tester);
      expect(find.text('다시 봐도 명작'), findsOneWidget);
    });

    testWidgets('403(내 평점이 아님)은 Dialog에 서버 문구만 보이고 로그아웃하지 않는다', (tester) async {
      await open(tester);
      h.ratingApi.failures['update'] = apiFailure(
        '/ratings/2',
        403,
        code: 'RATING403_1',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);

      expect(find.byType(MovieRatingDialog), findsOneWidget);
      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(authOf(tester).isSignedIn, isTrue);
      expect(h.storage.token, isNotNull);
      expect(currentLocation(tester), AppRoutes.myRatings);
    });

    testWidgets('토큰 만료(AUTH401_3)면 세션을 정리하고 로그인 화면에서 만료를 한 번 안내한다', (
      tester,
    ) async {
      await open(tester);
      h.ratingApi.failures['update'] = apiFailure(
        '/ratings/2',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);

      expect(authOf(tester).isSignedIn, isFalse);
      expect(h.storage.token, isNull);
      expect(currentLocation(tester), AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      // 만료 안내는 한 번만 뜬다.
      expect(find.text(sessionExpiredMessage), findsOneWidget);
      // 열려 있던 수정 Dialog가 로그인 화면 위에 남아 있으면 안 된다.
      expect(find.byType(MovieRatingDialog), findsNothing);
    });

    testWidgets('수정하려는 평점이 서버에 이미 없으면(404) 문구를 보여주고 목록에서도 사라진다', (
      tester,
    ) async {
      await open(tester);
      h.ratingApi.serverRatings.remove(2);
      await tester.tap(_editButton(2));
      await settle(tester);
      await tester.tap(find.byKey(saveRatingButtonKey));
      await settle(tester);

      expect(find.text('해당 평점을 찾을 수 없습니다.'), findsOneWidget);
      await tester.tap(find.byKey(cancelRatingButtonKey));
      await settle(tester);
      expect(_tile(2), findsNothing);
      expect(_tile(1), findsOneWidget);
    });
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
      expect(h.ratingApi.deletedIds, isEmpty);
      expect(_tile(1), findsOneWidget);
    });

    testWidgets('확인하면 삭제되고 목록이 갱신되며, 마지막 항목을 지우면 Empty가 보인다', (tester) async {
      await open(tester);
      await tester.tap(_deleteButton(2));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);

      expect(h.ratingApi.deletedIds, [2]);
      expect(_tile(2), findsNothing);
      expect(_tile(1), findsOneWidget);
      expect(find.text('평점을 삭제했어요.'), findsOneWidget);

      await tester.tap(_deleteButton(1));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);
      expect(find.byKey(myRatingsEmptyKey), findsOneWidget);
      expect(find.text('이번 로그인에서 등록한 평점이 없어요.'), findsOneWidget);
      expect(
        find.byKey(myRatingsEditToggleKey),
        findsNothing,
      ); // 평점이 없으면 편집할 수 없다
    });

    testWidgets('삭제 요청 중에는 Dialog가 유지되고 닫히지 않는다', (tester) async {
      await open(tester);
      h.ratingApi.writeGate = Completer<void>();
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

      h.ratingApi.writeGate!.complete();
      await settle(tester);
      expect(find.text('평점을 삭제할까요?'), findsNothing);
      expect(_tile(1), findsNothing);
    });

    testWidgets('삭제 실패: Dialog에 서버 문구가 보이고 로딩이 풀려 다시 시도할 수 있다', (tester) async {
      await open(tester);
      h.ratingApi.failures['delete'] = apiFailure(
        '/ratings/1',
        403,
        code: 'RATING403_1',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await tester.tap(_deleteButton(1));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);

      expect(find.byKey(deleteRatingErrorKey), findsOneWidget);
      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(elevated(tester, deleteRatingConfirmKey).onPressed, isNotNull);
      expect(authOf(tester).isSignedIn, isTrue); // 403은 로그아웃이 아니다

      h.ratingApi.failures.clear();
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);
      expect(_tile(1), findsNothing);
    });

    testWidgets('삭제 중 토큰이 무효(AUTH401_2)면 로그인 화면으로 가고 Dialog는 남지 않는다', (
      tester,
    ) async {
      await open(tester);
      h.ratingApi.failures['delete'] = apiFailure(
        '/ratings/1',
        401,
        code: 'AUTH401_2',
        message: '유효하지 않은 토큰입니다.',
      );
      await tester.tap(_deleteButton(1));
      await settle(tester);
      await tester.tap(find.byKey(deleteRatingConfirmKey));
      await settle(tester);

      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
      expect(find.text('평점을 삭제할까요?'), findsNothing);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
    });
  });

  group('편집 · 다중 선택 삭제 (Challenge)', () {
    testWidgets('편집을 누르면 수정·삭제 버튼 대신 체크박스가 보이고, 취소하면 기본 목록으로 돌아온다', (
      tester,
    ) async {
      await open(tester, four: true);
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
      await open(tester, four: true);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(4));
      await tester.tap(_tile(2));
      await settle(tester);

      h.ratingApi.writeGate = Completer<void>();
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

      h.ratingApi.writeGate!.complete();
      await settle(tester);
      expect(h.ratingApi.deletedIds, [4, 2]);
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
      await open(tester, four: true);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(4));
      await tester.tap(_tile(2));
      await settle(tester);
      expect(elevated(tester, deleteSelectedButtonKey).onPressed, isNotNull);

      h.ratingApi.writeGate = Completer<void>();
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

      h.ratingApi.writeGate!.complete();
      await settle(tester);
      expect(h.ratingApi.deletedIds, hasLength(2));
    });

    testWidgets('일부만 실패하면 성공한 항목만 사라지고, 실패 개수를 Snackbar로 알리며 선택은 유지된다', (
      tester,
    ) async {
      h.ratingApi.failDeleteIds.add(3);
      await open(tester, four: true);
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
      await open(tester, four: true);
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(2));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedButtonKey));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedCancelKey));
      await settle(tester);

      expect(h.ratingApi.deletedIds, isEmpty);
      expect(tester.widget<Checkbox>(_checkbox(2)).value, isTrue); // 선택은 그대로
    });

    testWidgets('선택 삭제 중 토큰이 만료되면 나머지는 보내지 않고 로그인 화면으로 간다', (tester) async {
      await open(tester, four: true);
      h.ratingApi.failures['delete'] = apiFailure(
        '/ratings/4',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      await tester.tap(find.byKey(myRatingsEditToggleKey));
      await settle(tester);
      await tester.tap(_tile(4));
      await tester.tap(_tile(3));
      await tester.tap(_tile(2));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedButtonKey));
      await settle(tester);
      await tester.tap(find.byKey(deleteSelectedConfirmKey));
      await settle(tester);

      expect(h.ratingApi.deletedIds, [4], reason: '첫 401 뒤에는 요청을 더 보내지 않는다');
      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
    });
  });
}
