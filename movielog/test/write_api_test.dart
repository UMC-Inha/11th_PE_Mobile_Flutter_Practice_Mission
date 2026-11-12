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
import 'package:movielog/view_models/write_error_message.dart';

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

    test(
      'createRating: POST /members/{id}/ratings, 201만 성공이고 result 모양은 읽지 않는다',
      () async {
        for (final result in <Object?>[
          7,
          null,
          {'ratingId': 7},
        ]) {
          useAdapter(
            (options) => (
              201,
              {
                'isSuccess': true,
                'code': 'COMMON201',
                'message': 'ok',
                'result': result,
              },
            ),
          );
          await service.createRating(
            memberId: 11,
            request: const CreateRatingRequest(
              movieId: 550,
              score: 4,
              comment: '좋다',
            ),
          );
          final request = adapter.requests.single;
          expect(request.method, 'POST');
          expect(request.path, '/members/11/ratings');
          expect(request.data, {'movieId': 550, 'score': 4, 'comment': '좋다'});
        }
      },
    );

    test('createRating: 201이 아닌 성공 응답은 계약 위반(StateError)', () async {
      useAdapter((options) => (200, {'isSuccess': true}));
      await expectLater(
        service.createRating(
          memberId: 11,
          request: const CreateRatingRequest(movieId: 550, score: 4),
        ),
        throwsStateError,
      );
    });

    test('updateRating: PATCH에 score와 comment를 항상 실어 보낸다', () async {
      useAdapter((options) => (200, {'isSuccess': true, 'result': null}));
      await service.updateRating(
        memberId: 11,
        ratingId: 5,
        request: const UpdateRatingRequest(score: 2),
      );
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/members/11/ratings/5');
      expect(request.data, {'score': 2, 'comment': null});
    });

    test('deleteRating: 204는 body가 없으므로 JSON으로 파싱하지 않는다', () async {
      useAdapter((options) => (204, null));
      await service.deleteRating(memberId: 11, ratingId: 5);
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/members/11/ratings/5');
    });

    test('deleteRating: 204가 아니면 StateError', () async {
      useAdapter((options) => (200, {'isSuccess': true}));
      await expectLater(
        service.deleteRating(memberId: 11, ratingId: 5),
        throwsStateError,
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

    test('code 문자열이 바뀌어도(COMMON403 → RATING403_1) 같은 문구와 같은 동작이다', () {
      for (final code in ['COMMON403', 'RATING403_1', 'RATING4031']) {
        final error = responseError(
          403,
          failureBody(code, '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
        );
        expect(writeErrorMessage(error), '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');
        expect(shouldRefreshAfterRatingError(error), isTrue);
      }
    });

    test('403·404만 목록을 다시 조회하고 400·409·500은 다시 조회하지 않는다', () {
      bool refresh(int status) => shouldRefreshAfterRatingError(
        responseError(status, failureBody('X', '문구')),
      );
      expect(refresh(403), isTrue);
      expect(refresh(404), isTrue);
      expect(refresh(400), isFalse);
      expect(refresh(409), isFalse);
      expect(refresh(500), isFalse);
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
