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

import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';

Widget _detailApp(FakeRatingApiService service, {int? memberId = 7}) {
  final movie = FakeTmdbMovieService().movie(550);
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MovieDetailViewModel>(
      create: (_) => MovieDetailViewModel(service, memberId, movie),
      child: const MovieDetailScreen(),
    ),
  );
}

Widget _myRatingsApp(FakeRatingApiService service) {
  return MaterialApp(
    theme: AppTheme.light,
    home: ChangeNotifierProvider<MyRatingsViewModel>(
      create: (_) =>
          MyRatingsViewModel(service, FakeTmdbMovieService(), 7)..load(),
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
    test('TMDB id를 movieId로, 세션 memberId를 path로 등록한다', () async {
      final service = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(
        service,
        7,
        FakeTmdbMovieService().movie(550),
      );
      await viewModel.createRating(score: 4, comment: '재밌어요');

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(service.createRequests.single, {
        'memberId': 7,
        'movieId': 550,
        'score': 4,
        'comment': '재밌어요',
      });
    });

    test('409는 서버 message를 그대로 보여준다', () async {
      final service = FakeRatingApiService()
        ..writeFailStatus = 409
        ..writeFailMessage = '이미 이 영화에 평점을 남기셨습니다.';
      final viewModel = MovieDetailViewModel(
        service,
        7,
        FakeTmdbMovieService().movie(550),
      );
      await viewModel.createRating(score: 4);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
    });

    test('회원가입 전이면 요청을 보내지 않는다', () async {
      final service = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(
        service,
        null,
        FakeTmdbMovieService().movie(550),
      );
      await viewModel.createRating(score: 4);

      expect(viewModel.canRate, isFalse);
      expect(service.createRequests, isEmpty);
    });
  });

  group('MyRatingsViewModel', () {
    test('수정 성공 뒤 목록을 다시 조회한다', () async {
      final service = FakeRatingApiService(ratings: [sampleRating()]);
      final viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 7);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 3, comment: '다시 보니 보통');
      expect(service.fetchCount, 2);
      expect(viewModel.ratings.single.rating.score, 3);
      expect(viewModel.ratings.single.rating.comment, '다시 보니 보통');
    });

    test('403은 권한 문구로 실패를 알리고 목록을 서버 상태와 맞춘다', () async {
      final service = FakeRatingApiService(ratings: [sampleRating()])
        ..writeFailStatus = 403
        ..writeFailMessage = '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.';
      final viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 7);
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
      expect(service.fetchCount, 2);
    });

    test('400·409는 다시 조회하지 않는다', () async {
      final service = FakeRatingApiService(ratings: [sampleRating()])
        ..writeFailStatus = 400
        ..writeFailMessage = '별점은 5점 이하여야 합니다.';
      final viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 7);
      await viewModel.load();

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 5),
        throwsA(isA<RatingWriteException>()),
      );
      expect(service.fetchCount, 1);
    });

    test('저장은 성공하고 재조회만 실패하면 저장 실패로 던지지 않고 경고만 남긴다', () async {
      final service = FakeRatingApiService(ratings: [sampleRating()])
        ..failNextFetchAfterWrite = true;
      final viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 7);
      await viewModel.load();

      await viewModel.deleteRating(1);
      expect(service.ratings, isEmpty);
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));

      // GET만 다시 시도하면 경고가 사라지고 Empty가 됩니다.
      service.failStatusCode = null;
      service.failNextFetchAfterWrite = false;
      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.empty);
      expect(viewModel.refreshWarning, isNull);
      expect(service.deleteRequests, [1]);
    });
  });

  group('영화 상세 평점 등록 화면', () {
    testWidgets('별점·코멘트를 입력해 등록하면 Dialog가 닫히고 성공 Snackbar가 보인다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService();
      await tester.pumpWidget(_detailApp(service));

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
      await tester.pumpWidget(_detailApp(service));

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

    testWidgets('회원가입 전에는 평점 남기기 버튼이 비활성화되고 안내가 보인다', (tester) async {
      _usePhoneSize(tester);
      await tester.pumpWidget(_detailApp(FakeRatingApiService(), memberId: null));

      expect(find.text('학습용 회원가입을 완료하면 평점을 남길 수 있어요.'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('평점 남기기'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('내가 등록한 평점 수정·삭제 화면', () {
    testWidgets('수정 버튼을 누르면 기존 별점·코멘트가 채워진 Dialog가 뜨고, 저장 뒤 목록이 갱신된다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService(
        ratings: [sampleRating(score: 5, comment: '최고의 영화!')],
      );
      await tester.pumpWidget(_myRatingsApp(service));
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
      await tester.pumpWidget(_myRatingsApp(service));
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
      await tester.pumpWidget(_myRatingsApp(service));
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

    testWidgets('삭제 성공 뒤 재조회만 실패하면 조회 재시도 안내를 보여주고 GET만 다시 시도한다', (tester) async {
      _usePhoneSize(tester);
      final service = FakeRatingApiService(ratings: [sampleRating()])
        ..failNextFetchAfterWrite = true;
      await tester.pumpWidget(_myRatingsApp(service));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('삭제'));
      await tester.pumpAndSettle();

      expect(find.textContaining('저장은 완료됐지만 목록을 불러오지 못했습니다.'), findsOneWidget);

      service
        ..failStatusCode = null
        ..failNextFetchAfterWrite = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(service.deleteRequests, [1]); // DELETE는 다시 보내지 않습니다.
      expect(find.text('아직 등록된 평점이 없어요.'), findsOneWidget);
    });
  });
}
