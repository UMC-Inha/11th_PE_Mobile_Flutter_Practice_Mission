import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/screens/detail/movie_detail_screen.dart';
import 'package:movielog/screens/detail/widgets/rating_dialog.dart';
import 'package:movielog/screens/my_ratings/my_ratings_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import 'fakes/fake_auth.dart';
import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';

Future<Widget> _detailApp(FakeRatingApiService service) async {
  final movie = FakeTmdbMovieService().movie(550);
  final auth = await signedInAuth();
  final store = SessionRatingStore(auth);
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MovieDetailViewModel>(
      create: (_) => MovieDetailViewModel(service, auth, store, movie),
      child: const MovieDetailScreen(),
    ),
  );
}

/// 현재 세션에서 service의 평점을 등록한 상태로 시작합니다.
Future<(MyRatingsViewModel, SessionRatingStore)> _myRatings(
  FakeRatingApiService service,
) async {
  final auth = await signedInAuth();
  final store = SessionRatingStore(auth);
  for (final rating in service.ratings) {
    store.upsert(rating, sessionVersion: auth.sessionVersion);
  }
  return (MyRatingsViewModel(service, FakeTmdbMovieService(), auth, store), store);
}

Future<Widget> _myRatingsApp(FakeRatingApiService service) async {
  final (viewModel, _) = await _myRatings(service);
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MyRatingsViewModel>(
      create: (_) => viewModel..load(),
      child: const MyRatingsScreen(),
    ),
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _dialogButton(String label) => find.descendant(
  of: find.byType(Dialog),
  matching: find.widgetWithText(ElevatedButton, label),
);

void main() {
  group('요청·응답 Model', () {
    test('CommonResponse는 result payload를 제네릭으로 파싱하고, result가 없으면 null이다', () {
      final success = CommonResponse<SignUpResult>.fromJson(
        {
          'isSuccess': true,
          'code': 'COMMON201',
          'message': '성공',
          'result': {'memberId': 12, 'email': 'a@b.com', 'nickname': '무비'},
        },
        (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
      );
      expect(success.result?.memberId, 12);

      final failure = CommonResponse.tryParseError({
        'isSuccess': false,
        'code': 'COMMON409',
        'message': '이미 사용 중인 이메일입니다.',
        'result': null,
      });
      expect(failure?.code, 'COMMON409');
      expect(failure?.result, isNull);
      // 공통 형식이 아닌 body는 null입니다.
      expect(CommonResponse.tryParseError({'error': 'Not Found'}), isNull);
    });

    test('등록 요청은 빈 코멘트를 생략하고, 수정 요청은 comment를 항상 보낸다', () {
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: '  ').toJson(),
        {'movieId': 550, 'score': 4},
      );
      expect(
        const CreateRatingRequest(movieId: 550, score: 4, comment: ' 좋아요 ').toJson(),
        {'movieId': 550, 'score': 4, 'comment': '좋아요'},
      );
      expect(
        const UpdateRatingRequest(score: 3, comment: null).toJson(),
        {'score': 3, 'comment': null},
      );
    });

    test('서버 평점은 1~5 정수만 허용한다', () {
      expect(validateServerScore(3), 3);
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
    });
  });

  group('MovieDetailViewModel', () {
    test('TMDB id를 movieId로 등록하고 body에 memberId를 넣지 않는다', () async {
      final service = FakeRatingApiService();
      final auth = await signedInAuth();
      final viewModel = MovieDetailViewModel(
        service,
        auth,
        SessionRatingStore(auth),
        FakeTmdbMovieService().movie(550),
      );
      await viewModel.createRating(score: 4, comment: '재밌어요');

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(service.createRequests.single, {
        'movieId': 550,
        'score': 4,
        'comment': '재밌어요',
      });
    });

    test('409는 서버 message를 그대로 보여준다', () async {
      final service = FakeRatingApiService()
        ..writeFailStatus = 409
        ..writeFailMessage = '이미 이 영화에 평점을 남기셨습니다.';
      final auth = await signedInAuth();
      final viewModel = MovieDetailViewModel(
        service,
        auth,
        SessionRatingStore(auth),
        FakeTmdbMovieService().movie(550),
      );
      await viewModel.createRating(score: 4);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
    });

  });

  group('MyRatingsViewModel', () {
    test('수정 성공 뒤 수정 result로 목록을 갱신한다', () async {
      final service = FakeRatingApiService(ratings: [sampleRating()]);
      final (viewModel, _) = await _myRatings(service);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 3, comment: '다시 보니 보통');
      await viewModel.load();
      expect(viewModel.ratings.single.rating.score, 3);
      expect(viewModel.ratings.single.rating.comment, '다시 보니 보통');
    });

    test('403은 권한 문구로 실패를 알리고 목록은 그대로 둔다', () async {
      final service = FakeRatingApiService(ratings: [sampleRating()])
        ..writeFailStatus = 403
        ..writeFailCode = 'RATING403_1'
        ..writeFailMessage = '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.';
      final (viewModel, store) = await _myRatings(service);
      await viewModel.load();

      await expectLater(
        viewModel.deleteRating(1),
        throwsA(
          isA<RatingWriteException>().having(
            (e) => e.message,
            'message',
            '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
          ),
        ),
      );
      expect(store.ratings, hasLength(1));
    });

  });

  group('영화 상세 평점 등록 화면', () {
    testWidgets('별점·코멘트를 입력해 등록하면 Dialog가 닫히고 성공 Snackbar가 보인다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService();
      await tester.pumpWidget(await tester.runAsync(() => _detailApp(service)) as Widget);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDialog), matching: find.byIcon(Icons.star)).at(3));
      await tester.enterText(find.byType(TextField), '  재밌어요  ');
      await tester.pump();
      expect(find.text('4점'), findsOneWidget);

      service.writeGate = Completer<void>();
      await tester.tap(_dialogButton('확인'));
      await tester.pump();
      // 저장 중에는 확인 버튼이 로딩 상태이고 취소도 비활성입니다.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(_dialogButton('취소')).onPressed,
        isNull,
      );
      // 저장 중 뒤로가기로 닫히지 않습니다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);

      service.writeGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(service.createRequests.single['comment'], '재밌어요');
      expect(find.textContaining('평점을 등록했습니다.'), findsOneWidget);
      expect(find.text('내 평점 4'), findsOneWidget);
    });

    testWidgets('등록이 실패하면 Dialog에 서버 문구를 보여주고 입력을 유지한다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService()
        ..writeFailStatus = 409
        ..writeFailMessage = '이미 이 영화에 평점을 남기셨습니다.';
      await tester.pumpWidget(await tester.runAsync(() => _detailApp(service)) as Widget);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDialog), matching: find.byIcon(Icons.star)).at(2));
      await tester.enterText(find.byType(TextField), '두 번째 후기');
      await tester.pump();
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(find.text('두 번째 후기'), findsOneWidget);
      expect(find.text('3점'), findsOneWidget);

      await tester.tap(_dialogButton('취소'));
      await tester.pumpAndSettle();
      expect(find.textContaining('평점이 등록되지 않았어요.'), findsOneWidget);
    });

  });

  group('내가 등록한 평점 수정·삭제 화면', () {
    testWidgets('수정 버튼을 누르면 기존 별점·코멘트가 채워진 Dialog가 뜨고, 저장 뒤 목록이 갱신된다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService(
        ratings: [sampleRating(score: 5, comment: '최고의 영화!')],
      );
      await tester.pumpWidget(await tester.runAsync(() => _myRatingsApp(service)) as Widget);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '수정'));
      await tester.pumpAndSettle();
      expect(find.text('5점'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.text('최고의 영화!'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.descendant(of: find.byType(RatingDialog), matching: find.byIcon(Icons.star)).at(1));
      await tester.enterText(find.byType(TextField), '다시 보니 보통');
      await tester.pump();
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(service.updateRequests.single, {
        'ratingId': 1,
        'score': 2,
        'comment': '다시 보니 보통',
      });
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('다시 보니 보통'), findsOneWidget);
      expect(find.text('평점을 수정했어요.'), findsOneWidget);
    });

    testWidgets('코멘트가 null인 평점은 빈 칸으로 시작하고, 그대로 저장해도 null을 보낸다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService(ratings: [sampleRating(comment: null)]);
      await tester.pumpWidget(await tester.runAsync(() => _myRatingsApp(service)) as Widget);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '수정'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(_dialogButton('확인'));
      await tester.pumpAndSettle();
      expect(service.updateRequests.single['comment'], isNull);
    });

    testWidgets('삭제 확인에서 취소하면 요청이 없고, 삭제하면 마지막 항목 뒤 Empty UI를 보여준다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService(ratings: [sampleRating()]);
      await tester.pumpWidget(await tester.runAsync(() => _myRatingsApp(service)) as Widget);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      await tester.tap(_dialogButton('취소'));
      await tester.pumpAndSettle();
      expect(service.deleteRequests, isEmpty);
      expect(find.text('최고의 영화!'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.pumpAndSettle();
      service.writeGate = Completer<void>();
      await tester.tap(_dialogButton('삭제'));
      await tester.pump();
      // 삭제 중에는 Dialog가 유지되고 뒤로가기로 닫히지 않습니다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);

      service.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(service.deleteRequests, [1]);
      expect(find.text('평점을 삭제할까요?'), findsNothing);
      expect(find.text('아직 등록된 평점이 없어요.'), findsOneWidget);
    });

  });
}
