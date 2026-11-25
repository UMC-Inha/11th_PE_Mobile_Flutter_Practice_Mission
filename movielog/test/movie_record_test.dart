import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support.dart';

const _base = 'http://localhost:3000';
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzIn0.c2lnbmF0dXJlLXBhcnQ';

Map<String, Object?> _ratingJson(int ratingId, int movieId) => {
  'ratingId': ratingId,
  'movieId': movieId,
  'score': 4,
  'comment': '좋았다',
  'createdAt': '2026-11-22T00:00:00.000Z',
  'updatedAt': '2026-11-22T00:00:00.000Z',
};

Map<String, Object?> _created(Object? result) => {
  'isSuccess': true,
  'code': 'COMMON201',
  'message': '성공',
  'result': result,
};

void main() {
  group('CreateMovieRecordRequest', () {
    test('addToFavorites는 필수 bool이라 false여도 항상 보낸다(memberId는 없다)', () {
      expect(
        const CreateMovieRecordRequest(
          movieId: 550,
          score: 4,
          addToFavorites: false,
        ).toJson(),
        {'movieId': 550, 'score': 4, 'addToFavorites': false},
      );
      expect(
        const CreateMovieRecordRequest(
          movieId: 550,
          score: 5,
          comment: '  최고  ',
          addToFavorites: true,
        ).toJson(),
        {'movieId': 550, 'score': 5, 'comment': '최고', 'addToFavorites': true},
      );
    });

    test('코멘트가 비었거나 공백뿐이면 comment 키를 생략한다', () {
      for (final comment in [null, '', '   ']) {
        expect(
          CreateMovieRecordRequest(
            movieId: 1,
            score: 3,
            comment: comment,
            addToFavorites: true,
          ).toJson().containsKey('comment'),
          isFalse,
          reason: '"$comment"',
        );
      }
    });
  });

  group('MovieRecordResponseDto', () {
    test('평점은 기존 평점 DTO, 즐겨찾기는 기존 즐겨찾기 DTO를 재사용한다', () {
      final dto = MovieRecordResponseDto.fromJson({
        'rating': _ratingJson(7, 550),
        'favorite': {
          'favoriteId': 3,
          'movieId': 550,
          'createdAt': '2026-11-22T00:00:00.000Z',
        },
      });
      expect(dto.rating.ratingId, 7);
      expect(dto.rating.comment, '좋았다');
      expect(dto.favorite?.favoriteId, 3);
    });

    test('addToFavorites가 false였으면 favorite은 null이다', () {
      final dto = MovieRecordResponseDto.fromJson({
        'rating': _ratingJson(7, 550),
        'favorite': null,
      });
      expect(dto.favorite, isNull);
    });

    test('rating이 없거나 객체가 아니면 형식 오류', () {
      expect(() => MovieRecordResponseDto.fromJson(null), throwsFormatException);
      expect(
        () => MovieRecordResponseDto.fromJson({'favorite': null}),
        throwsFormatException,
      );
    });
  });

  group('MovieRecordApiService', () {
    late FakeTokenStorage storage;

    setUp(() => storage = FakeTokenStorage(token: _jwt));

    (MovieRecordApiService, StubAdapter) build(
      (int, Object?) Function(RequestOptions) respond,
    ) {
      final adapter = StubAdapter(respond);
      final dio = createAuthMovieLogApiClient(
        storage,
        baseUrl: _base,
        enableLogging: false,
      )..httpClientAdapter = adapter;
      return (MovieRecordApiService(dio), adapter);
    }

    test('POST /movie-records: 보호 Client라 Bearer가 붙고 201 result를 읽는다', () async {
      final (service, adapter) = build(
        (_) => (
          201,
          _created({'rating': _ratingJson(7, 550), 'favorite': null}),
        ),
      );
      final result = await service.createRecord(
        const CreateMovieRecordRequest(
          movieId: 550,
          score: 4,
          comment: '좋았다',
          addToFavorites: true,
        ),
      );
      expect(result.rating.ratingId, 7);
      expect(result.favorite, isNull);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/movie-records');
      expect(request.headers['Authorization'], 'Bearer $_jwt');
      expect(request.data, {
        'movieId': 550,
        'score': 4,
        'comment': '좋았다',
        'addToFavorites': true,
      });
    });

    test('201이 아닌 성공 응답과 result 없는 응답은 StateError로 막는다', () async {
      final (service, _) = build(
        (_) => (200, _created({'rating': _ratingJson(7, 550)})),
      );
      await expectLater(
        service.createRecord(
          const CreateMovieRecordRequest(
            movieId: 550,
            score: 4,
            addToFavorites: false,
          ),
        ),
        throwsA(isA<StateError>()),
      );
      final (service2, _) = build((_) => (201, _created(null)));
      await expectLater(
        service2.createRecord(
          const CreateMovieRecordRequest(
            movieId: 550,
            score: 4,
            addToFavorites: false,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('서버의 오류 code를 그대로 전달한다(RATING409_1·FAVORITE409_1·MEMBER404_1·COMMON400)', () async {
      for (final (status, code) in [
        (409, 'RATING409_1'),
        (409, 'FAVORITE409_1'),
        (404, 'MEMBER404_1'),
        (400, 'COMMON400'),
      ]) {
        final (service, _) = build(
          (_) => (
            status,
            {'isSuccess': false, 'code': code, 'message': '실패', 'result': null},
          ),
        );
        try {
          await service.createRecord(
            const CreateMovieRecordRequest(
              movieId: 550,
              score: 4,
              addToFavorites: true,
            ),
          );
          fail('DioException이 나와야 한다');
        } on DioException catch (error) {
          expect(apiErrorCode(error), code);
        }
      }
    });
  });

  group('MovieDetailViewModel.saveMovieRecord', () {
    late FakeTmdbMovieService tmdb;
    late FakeRatingApiService ratingApi;
    late FakeFavoriteApiService favoriteApi;
    late FakeMovieRecordApiService recordApi;
    late FakeTokenStorage storage;
    late FakeAuthApiService authApi;
    late FakeMemberApiService memberApi;
    late AuthViewModel auth;
    late SessionRatings session;
    late MovieDetailViewModel vm;

    setUp(() async {
      tmdb = FakeTmdbMovieService(delay: Duration.zero);
      ratingApi = FakeRatingApiService();
      favoriteApi = FakeFavoriteApiService()..delay = Duration.zero;
      recordApi = FakeMovieRecordApiService(
        ratingApi: ratingApi,
        favoriteApi: favoriteApi,
        delay: Duration.zero,
      );
      storage = FakeTokenStorage();
      authApi = FakeAuthApiService();
      memberApi = FakeMemberApiService();
      auth = AuthViewModel(authApi, memberApi, storage);
      session = SessionRatings(auth);
      await auth.login('kevin@umc.com', 'Password1234!');
      vm = MovieDetailViewModel(
        tmdb,
        ratingApi,
        auth,
        session,
        movieRecordApi: recordApi,
        movieId: 550,
        movie: movie(550),
      );
    });

    tearDown(() {
      vm.dispose();
      session.dispose();
      auth.dispose();
    });

    test('즐겨찾기도 추가하면 평점과 즐겨찾기가 한 번의 요청으로 서버에 저장된다', () async {
      final result = await vm.saveMovieRecord(
        score: 4,
        comment: ' 좋았다 ',
        addToFavorites: true,
      );
      expect(result.isSaved, isTrue);
      expect(recordApi.requests, hasLength(1));
      expect(recordApi.requests.single.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '좋았다',
        'addToFavorites': true,
      });
      expect(ratingApi.createdRequests, isEmpty, reason: 'POST /ratings는 부르지 않는다');
      expect(favoriteApi.addCalls, isEmpty, reason: 'POST /favorites도 따로 부르지 않는다');
      expect(favoriteApi.isFavoriteOf(550), isTrue);
      expect(result.record!.favorite, isNotNull);
      expect(vm.myRating?.score, 4);
      expect(vm.submitStatus, SubmitStatus.success);
      // 응답의 평점은 이번 세션 목록에 들어가 마이페이지에서 수정·삭제할 수 있다.
      expect(session.ratings.single.movieId, 550);
    });

    test('체크하지 않으면 addToFavorites=false로 평점만 저장하고 favorite은 null이다', () async {
      final result = await vm.saveMovieRecord(score: 5, addToFavorites: false);
      expect(result.isSaved, isTrue);
      expect(recordApi.requests.single.addToFavorites, isFalse);
      expect(result.record!.favorite, isNull);
      expect(favoriteApi.isFavoriteOf(550), isFalse);
    });

    test('RATING409_1은 Dialog를 닫는 실패이고 서버 message를 그대로 안내한다', () async {
      ratingApi.serverRatings[1] = memberRating(1, 550);
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(result.isSaved, isFalse);
      expect(result.closesDialog, isTrue);
      expect(result.message, '이미 이 영화에 평점을 남기셨습니다.');
      expect(favoriteApi.isFavoriteOf(550), isFalse, reason: '평점이 막히면 즐겨찾기도 저장되지 않는다');
      expect(vm.submitStatus, SubmitStatus.error);
    });

    test('FAVORITE409_1은 Dialog를 닫는 실패이고 평점도 저장되지 않았음을 함께 안내한다', () async {
      favoriteApi.seed([550]); // 화면은 모르는 사이에 이미 즐겨찾기됨
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(result.closesDialog, isTrue);
      expect(result.message, contains('이미 즐겨찾기한 영화입니다.'));
      expect(result.message, contains('평점은 저장되지 않았어요'));
      expect(ratingApi.serverRatings, isEmpty, reason: '평점도 저장되지 않는다');
      expect(session.ratings, isEmpty);
      expect(vm.myRating, isNull);
    });

    test('MEMBER404_1은 Dialog를 닫는 실패다', () async {
      recordApi.failure = apiFailure(
        '/movie-records',
        404,
        code: 'MEMBER404_1',
        message: '회원을 찾을 수 없습니다.',
      );
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(result.closesDialog, isTrue);
      expect(result.message, '회원을 찾을 수 없습니다.');
    });

    test('COMMON400은 Dialog를 열어 둔 채 서버 message를 보여 주는 실패다', () async {
      recordApi.failure = apiFailure(
        '/movie-records',
        400,
        code: 'COMMON400',
        message: '요청 값이 올바르지 않습니다.',
      );
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(result.closesDialog, isFalse);
      expect(result.message, '요청 값이 올바르지 않습니다.');
      expect(vm.submitStatus, SubmitStatus.error);
    });

    test('네트워크 실패도 Dialog를 열어 둔다(원인 문구)', () async {
      recordApi.failure = networkFailure('/movie-records');
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(result.closesDialog, isFalse);
      expect(result.message, contains('네트워크'));
      expect(auth.isSignedIn, isTrue, reason: '네트워크 실패는 로그아웃이 아니다');
    });

    test('timeout이면 같은 POST를 자동으로 다시 보내지 않고, 다시 누르면 RATING409_1로 알려 준다', () async {
      recordApi.timeoutAfterApply = true;
      final first = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(first.closesDialog, isFalse);
      expect(first.message, contains('응답이 늦어'));
      expect(recordApi.requests, hasLength(1), reason: '자동 재시도 없음');

      recordApi.timeoutAfterApply = false;
      final second = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(second.closesDialog, isTrue, reason: '서버에는 이미 저장되어 있다');
      expect(second.message, contains('이미 이 영화에 평점을 남기셨습니다.'));
    });

    test('만료 code는 세션을 한 번 정리하고 Dialog를 닫지 않는다', () async {
      recordApi.failure = apiFailure(
        '/movie-records',
        401,
        code: 'AUTH401_3',
        message: '토큰 만료',
      );
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(auth.isSignedIn, isFalse);
      expect(auth.sessionExpired, isTrue);
      expect(storage.deletes, 1);
      expect(result.closesDialog, isFalse);
    });

    test('로그인하지 않았으면 요청을 보내지 않는다', () async {
      await auth.logout();
      final result = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(result.isSaved, isFalse);
      expect(recordApi.requests, isEmpty);
    });

    test('요청 중에 또 부르면 무시한다(중복 탭)', () async {
      recordApi.gate = Completer<void>();
      final first = vm.saveMovieRecord(score: 4, addToFavorites: true);
      final second = await vm.saveMovieRecord(score: 4, addToFavorites: true);
      expect(second.isIgnored, isTrue);
      recordApi.gate!.complete();
      expect((await first).isSaved, isTrue);
      expect(recordApi.requests, hasLength(1));
    });

    test('응답이 로그아웃 뒤에 도착하면 이번 세션 목록에 넣지 않는다', () async {
      recordApi.gate = Completer<void>();
      final saving = vm.saveMovieRecord(score: 4, addToFavorites: true);
      await auth.logout();
      recordApi.gate!.complete();
      final result = await saving;
      expect(result.isIgnored, isTrue);
      expect(session.ratings, isEmpty);
      expect(vm.myRating, isNull);
    });
  });
}
