import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/log_redaction.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';

import 'support.dart';

const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzIiwiZW1haWwiOiJhQGIuY29tIn0.c2lnbmF0dXJlLXBhcnQ';

void main() {
  group('LoginRequest · LoginResult', () {
    test('요청: 이메일은 trim하고 비밀번호는 그대로 보낸다', () {
      const request = LoginRequest(
        email: '  kevin@umc.com ',
        password: ' Pass 1234! ',
      );
      expect(request.toJson(), {
        'email': 'kevin@umc.com',
        'password': ' Pass 1234! ',
      });
    });

    test('요청: 로그·오류 출력에 섞여도 비밀번호가 나가지 않는다', () {
      const request = LoginRequest(email: 'a@b.com', password: 'Secret1234!');
      expect('$request', isNot(contains('Secret1234!')));
      expect('$request', contains('a@b.com'));
    });

    test('결과: nickname과 accessToken만 읽고 memberId는 없다', () {
      final result = LoginResult.fromJson({
        'nickname': '케빈',
        'accessToken': _jwt,
      });
      expect(result.nickname, '케빈');
      expect(result.accessToken, _jwt);
      // 응답에 없는 필드를 추정하지 않는다: 모델에 memberId 자체가 없다.
      expect(result.toString(), isNot(contains('memberId')));
    });

    test('결과: toString에 토큰 원문이 섞이지 않는다', () {
      const result = LoginResult(nickname: '케빈', accessToken: _jwt);
      expect('$result', isNot(contains(_jwt)));
      expect('$result', isNot(contains('eyJ')));
    });

    test('결과: 필수 필드가 없으면 오류다(조용히 빈 토큰을 만들지 않는다)', () {
      expect(
        () => LoginResult.fromJson({'nickname': '케빈'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('MemberInfo', () {
    test('이메일·닉네임·가입일을 읽고 memberId는 없다', () {
      final member = MemberInfo.fromJson({
        'email': 'kevin@umc.com',
        'nickname': '케빈',
        'createdAt': '2026-10-10T12:00:00',
      });
      expect(member.email, 'kevin@umc.com');
      expect(member.nickname, '케빈');
      expect(member.createdAt, DateTime(2026, 10, 10, 12));
    });

    test('가입일은 "2026.10.10 가입" 형식이다(한 자리 월·일은 0을 채운다)', () {
      expect(testMember().joinedLabel, '2026.10.10 가입');
      final early = MemberInfo(
        email: 'a@b.com',
        nickname: '가나',
        createdAt: DateTime(2026, 3, 5, 12),
      );
      expect(early.joinedLabel, '2026.03.05 가입');
    });

    test('parseMemberInfo: 공통 응답 틀의 result를 읽는다', () {
      final member = parseMemberInfo({
        'isSuccess': true,
        'code': 'COMMON200',
        'message': '회원 정보를 조회했습니다.',
        'result': {
          'email': 'kevin@umc.com',
          'nickname': '케빈',
          'createdAt': '2026-10-10T12:00:00',
        },
      });
      expect(member.nickname, '케빈');
    });

    test('parseMemberInfo: 틀이 어긋나면 StateError', () {
      expect(() => parseMemberInfo('html'), throwsStateError);
      expect(
        () => parseMemberInfo({
          'isSuccess': true,
          'code': 'COMMON200',
          'message': 'ok',
          'result': null,
        }),
        throwsStateError,
      );
    });
  });

  group('api_error', () {
    DioException error(Object? data) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 401,
        data: data,
      ),
    );

    test('code와 message를 공통 실패 응답에서 꺼낸다', () {
      final e = apiFailure(
        '/x',
        401,
        code: 'AUTH401_3',
        message: '유효하지 않은 토큰입니다.',
      );
      expect(apiErrorCode(e), 'AUTH401_3');
      expect(apiErrorMessage(e), '유효하지 않은 토큰입니다.');
    });

    test('틀이 아니거나 필드 타입이 다르면 null', () {
      for (final data in [
        null,
        '<html>',
        <String, Object?>{'code': 401},
      ]) {
        expect(apiErrorCode(error(data)), isNull);
      }
      expect(apiErrorMessage(error({'message': 5})), isNull);
    });

    test('세션 만료 code는 AUTH401_2/3/4뿐이다(AUTH401_1·403·404는 아니다)', () {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        expect(isSessionExpiredCode(code), isTrue, reason: code);
      }
      for (final code in [
        'AUTH401_1',
        'RATING403_1',
        'RATING404_1',
        'COMMON401',
        null,
      ]) {
        expect(isSessionExpiredCode(code), isFalse, reason: '$code');
      }
    });
  });

  group('로그 가림', () {
    test('민감한 키의 값을 깊이 가린다(대소문자 무관)', () {
      final redacted = redactSensitive({
        'isSuccess': true,
        'result': {
          'nickname': '케빈',
          'accessToken': _jwt,
          'Password': 'Secret1234!',
          'nested': [
            {'TOKEN': 'abc'},
            {'authorization': 'Bearer xyz'},
          ],
        },
      }) as Map;
      final text = '$redacted';
      expect(text, contains('케빈'));
      expect(text, isNot(contains(_jwt)));
      expect(text, isNot(contains('Secret1234!')));
      expect(text, isNot(contains('abc')));
      expect(text, isNot(contains('xyz')));
      expect(text, contains('***'));
    });

    test('키 이름으로 못 거른 문자열 속 JWT 모양도 가린다', () {
      final masked = maskJwtLike('토큰은 $_jwt 입니다');
      expect(masked, isNot(contains('eyJ')));
      expect(masked, contains('***'));
      // JWT가 아닌 문자열은 건드리지 않는다.
      expect(maskJwtLike('일반 문장 eyJ 만 있음'), '일반 문장 eyJ 만 있음');
    });
  });
}
