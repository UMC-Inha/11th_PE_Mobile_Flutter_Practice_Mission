import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/view_models/write_error_message.dart';

import 'support.dart';

/// 요청을 기록하고 정해 둔 응답을 돌려주는 Dio 어댑터. 204처럼 본문이 없는 응답도 만들 수 있다.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  /// (상태 코드, 본문). 본문이 null이면 body 없는 응답이다.
  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      body == null ? '' : (body is String ? body : jsonEncode(body)),
      status,
      headers: body == null || body is String
          ? {}
          : {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> failureBody(String code, String message) => {
  'isSuccess': false,
  'code': code,
  'message': message,
  'result': null,
};

void main() {
  group('요청 Model과 응답 Model', () {
    test('CommonResponse: 성공은 result를 파싱하고, 실패는 result가 null이다', () {
      final success = CommonResponse<SignUpResult>.fromJson({
        'isSuccess': true,
        'code': 'COMMON201',
        'message': '회원가입에 성공했습니다.',
        'result': {'memberId': 7, 'email': 'a@b.com', 'nickname': '케빈'},
      }, (value) => SignUpResult.fromJson(value as Map<String, dynamic>));
      expect(success.isSuccess, isTrue);
      expect(success.result!.memberId, 7);
      expect(success.result!.nickname, '케빈');

      final failure = CommonResponse<SignUpResult>.fromJson(
        failureBody('COMMON409', '이미 사용 중인 이메일입니다.'),
        (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
      );
      expect(failure.isSuccess, isFalse);
      expect(failure.code, 'COMMON409');
      expect(failure.result, isNull);
    });

    test('CommonResponse: result가 숫자여도 정해 둔 파서로 읽는다', () {
      final response = CommonResponse<int>.fromJson({
        'isSuccess': true,
        'code': 'COMMON201',
        'message': 'ok',
        'result': 42,
      }, (value) => (value as num).toInt());
      expect(response.result, 42);
    });

    test('SignUpResult: memberId가 num이면 int로 바꾼다', () {
      final result = SignUpResult.fromJson({
        'memberId': 3.0,
        'email': 'a@b.com',
        'nickname': '케빈',
      });
      expect(result.memberId, 3);
    });

    test('CreateMemberRequest: 이메일·닉네임은 trim하고 비밀번호는 그대로 보낸다', () {
      const request = CreateMemberRequest(
        email: '  kevin@umc.com ',
        password: ' Pass 1234! ',
        nickname: ' 케빈 ',
      );
      expect(request.toJson(), {
        'email': 'kevin@umc.com',
        'password': ' Pass 1234! ', // 입력한 문자가 모두 의미 있다
        'nickname': '케빈',
      });
    });

    test('CreateMemberRequest: 로그·오류 출력에 섞여도 비밀번호가 나가지 않는다', () {
      const request = CreateMemberRequest(
        email: 'kevin@umc.com',
        password: 'Secret1234!',
        nickname: '케빈',
      );
      expect('$request', isNot(contains('Secret1234!')));
      expect('$request', contains('kevin@umc.com'));
    });

    test('CreateRatingRequest: 후기가 없거나 공백이면 comment 키를 아예 보내지 않는다', () {
      expect(const CreateRatingRequest(movieId: 550, score: 4).toJson(), {
        'movieId': 550,
        'score': 4,
      });
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: '   ',
        ).toJson(),
        {'movieId': 550, 'score': 4},
      );
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: ' 좋았다 ',
        ).toJson(),
        {'movieId': 550, 'score': 4, 'comment': '좋았다'},
      );
    });

    test('UpdateRatingRequest: score는 항상, comment는 비어 있으면 null로 명시해서 보낸다', () {
      expect(const UpdateRatingRequest(score: 3).toJson(), {
        'score': 3,
        'comment': null, // 키가 있는 null = "후기를 지운다"는 뜻을 분명히
      });
      expect(
        const UpdateRatingRequest(score: 5, comment: ' 다시 봐도 좋다 ').toJson(),
        {'score': 5, 'comment': '다시 봐도 좋다'},
      );
    });

    test('validateServerScore: 1~5 정수만 통과하고 반 점은 조용히 자르지 않고 막는다', () {
      for (final value in [1.0, 2.0, 3.0, 4.0, 5.0]) {
        expect(validateServerScore(value), value.toInt());
      }
      for (final value in [0.0, 0.5, 3.5, 4.9, 6.0, -1.0]) {
        expect(() => validateServerScore(value), throwsArgumentError);
      }
    });
  });

  group('MovieLogApiService 쓰기 API', () {
    late _Adapter adapter;
    late MovieLogApiService service;

    void useAdapter((int, Object?) Function(RequestOptions options) respond) {
      adapter = _Adapter(respond);
      service = MovieLogApiService(
        createMovieLogApiClient(
          baseUrl: 'http://localhost:3000',
          enableLogging: false,
        )..httpClientAdapter = adapter,
      );
    }

    test('signUp: POST /members에 JSON body를 보내고 201 공통 응답을 파싱한다', () async {
      useAdapter(
        (options) => (
          201,
          {
            'isSuccess': true,
            'code': 'COMMON201',
            'message': '회원가입에 성공했습니다.',
            'result': {
              'memberId': 11,
              'email': 'kevin@umc.com',
              'nickname': '케빈',
            },
          },
        ),
      );
      final response = await service.signUp(
        const CreateMemberRequest(
          email: 'kevin@umc.com ',
          password: 'Password1234!',
          nickname: '케빈',
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/members');
      expect(request.data, {
        'email': 'kevin@umc.com',
        'password': 'Password1234!',
        'nickname': '케빈',
      });
      expect(response.result!.memberId, 11);
    });
  });

  group('RatingApiService(토큰 기반, memberId 없음)', () {
    late _Adapter adapter;
    late FakeTokenStorage storage;
    late RatingApiService service;

    void useAdapter((int, Object?) Function(RequestOptions options) respond) {
      adapter = _Adapter(respond);
      storage = FakeTokenStorage(token: 'jwt-for-ratings');
      service = RatingApiService(
        createAuthMovieLogApiClient(
          storage,
          baseUrl: 'http://localhost:3000',
          enableLogging: false,
        )..httpClientAdapter = adapter,
      );
    }

    Map<String, Object?> ratingBody({
      int ratingId = 7,
      int score = 4,
      String? comment = '좋다',
    }) => {
      'isSuccess': true,
      'code': 'COMMON201',
      'message': 'ok',
      'result': {
        'ratingId': ratingId,
        'movieId': 550,
        'score': score,
        'comment': comment,
        'createdAt': '2026-11-18T01:00:00.000Z',
        'updatedAt': '2026-11-18T01:00:00.000Z',
      },
    };

    test(
      'createRating: POST /ratings, 요청 body·경로 어디에도 memberId가 없고 Bearer가 붙는다',
      () async {
        useAdapter((options) => (201, ratingBody()));
        final rating = await service.createRating(
          const CreateRatingRequest(movieId: 550, score: 4, comment: '좋다'),
        );

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/ratings');
        expect(request.data, {'movieId': 550, 'score': 4, 'comment': '좋다'});
        expect(request.headers['Authorization'], 'Bearer jwt-for-ratings');
        expect(request.data.toString(), isNot(contains('memberId')));
        expect(request.path, isNot(contains('members')));
        expect(rating.ratingId, 7);
        expect(rating.score, 4);
      },
    );

    test(
      'createRating: 201이 아닌 성공 응답과 result 없는 201은 계약 위반(StateError)',
      () async {
        useAdapter((options) => (200, ratingBody()));
        await expectLater(
          service.createRating(
            const CreateRatingRequest(movieId: 550, score: 4),
          ),
          throwsStateError,
        );

        useAdapter(
          (options) => (
            201,
            {
              'isSuccess': true,
              'code': 'COMMON201',
              'message': 'ok',
              'result': null,
            },
          ),
        );
        await expectLater(
          service.createRating(
            const CreateRatingRequest(movieId: 550, score: 4),
          ),
          throwsStateError,
        );
      },
    );

    test('updateRating: PATCH /ratings/{id}에 score와 comment를 항상 실어 보내고 수정된 평점을 돌려준다', () async {
      useAdapter(
        (options) => (200, ratingBody(ratingId: 5, score: 2, comment: null)),
      );
      final rating = await service.updateRating(
        ratingId: 5,
        request: const UpdateRatingRequest(score: 2),
      );
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/ratings/5');
      expect(request.data, {'score': 2, 'comment': null});
      expect(request.headers['Authorization'], 'Bearer jwt-for-ratings');
      expect(rating.ratingId, 5);
      expect(rating.score, 2);
      expect(rating.comment, isNull);
    });

    test(
      'deleteRating: DELETE /ratings/{id}는 200 + result null이 성공이다(204가 아니다)',
      () async {
        useAdapter(
          (options) => (
            200,
            {
              'isSuccess': true,
              'code': 'COMMON200',
              'message': 'ok',
              'result': null,
            },
          ),
        );
        await service.deleteRating(5);
        final request = adapter.requests.single;
        expect(request.method, 'DELETE');
        expect(request.path, '/ratings/5');
        expect(request.headers['Authorization'], 'Bearer jwt-for-ratings');
      },
    );

    test('deleteRating: 200이 아닌 성공 응답(예전 204)은 StateError다', () async {
      useAdapter((options) => (204, null));
      await expectLater(service.deleteRating(5), throwsStateError);
    });

    test('토큰이 저장돼 있지 않으면 Authorization 없이 나가 서버가 401로 답하게 둔다', () async {
      useAdapter((options) => (201, ratingBody()));
      storage.token = null;
      await service.createRating(
        const CreateRatingRequest(movieId: 550, score: 4),
      );
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('서버의 401 응답은 DioException으로 그대로 올라온다(AUTH401_3)', () async {
      useAdapter((options) => (401, failureBody('AUTH401_3', '토큰이 만료되었습니다.')));
      await expectLater(
        service.deleteRating(5),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
    });
  });

  group('오류 응답을 화면 문구로', () {
    DioException responseError(int status, Object? body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
    );

    test('서버 message를 그대로 쓰고, 같은 404도 문구를 새로 만들지 않는다', () {
      final noMember = responseError(
        404,
        failureBody('COMMON404', '존재하지 않는 유저입니다.'),
      );
      final noRating = responseError(
        404,
        failureBody('COMMON404', '존재하지 않는 평점입니다.'),
      );
      expect(writeErrorMessage(noMember), '존재하지 않는 유저입니다.');
      expect(writeErrorMessage(noRating), '존재하지 않는 평점입니다.');
      expect(
        writeSignUpErrorMessage(
          responseError(409, failureBody('COMMON409', '이미 사용 중인 이메일입니다.')),
        ),
        '이미 사용 중인 이메일입니다.',
      );
    });

    test('code 문자열이 바뀌어도(COMMON403 → RATING403_1) 같은 문구다', () {
      for (final code in ['COMMON403', 'RATING403_1', 'RATING4031']) {
        final error = responseError(
          403,
          failureBody(code, '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
        );
        expect(writeErrorMessage(error), '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');
      }
    });

    test('공통 틀이 아닌 본문(NestJS 기본 오류·HTML)은 null로 읽고 기본 문구를 쓴다', () {
      final nest = responseError(500, {
        'statusCode': 500,
        'message': 'Internal server error',
      });
      final html = responseError(502, '<html>Bad Gateway</html>');
      final empty = responseError(500, null);
      for (final error in [nest, html, empty]) {
        expect(parseErrorResponse(error), isNull);
        expect(writeErrorMessage(error), '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
      expect(writeSignUpErrorMessage(nest), '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    });

    test('서버가 꺼졌거나 시간이 초과되면 그 원인을 알려 준다', () {
      DioException transport(DioExceptionType type) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: type,
      );
      expect(
        writeErrorMessage(transport(DioExceptionType.connectionError)),
        '네트워크 상태를 확인하고 다시 시도해 주세요.',
      );
      expect(
        writeErrorMessage(transport(DioExceptionType.receiveTimeout)),
        '응답이 늦어지고 있어요. 다시 시도해 주세요.',
      );
    });
  });

  test('회원가입 요청의 비밀번호는 요청·응답 로그에 남지 않는다', () async {
    final logs = <String>[];
    final dio =
        createMovieLogApiClient(
            baseUrl: 'http://localhost:3000',
            enableLogging: true,
            log: logs.add,
          )
          ..httpClientAdapter = _Adapter(
            (options) => (409, failureBody('COMMON409', '이미 사용 중인 이메일입니다.')),
          );
    await expectLater(
      MovieLogApiService(dio).signUp(
        const CreateMemberRequest(
          email: 'kevin@umc.com',
          password: 'Secret1234!',
          nickname: '케빈',
        ),
      ),
      throwsA(isA<DioException>()),
    );
    final all = logs.join('\n');
    expect(all, contains('POST'));
    expect(all, contains('status=409'));
    expect(all, isNot(contains('Secret1234!')));
  });
}
